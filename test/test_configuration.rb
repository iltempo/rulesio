require "helper"
require "rulesio/railtie"
require "rulesio/girl_friday_queue"

MockController = Class.new

class TestConfiguration < Test::Unit::TestCase
  REDIS = APP = Object.new

  STRING_CONFIGURATION = <<-CONFIG
  token 'FOOF'
  queue RulesIO::GirlFridayQueue, :store => GirlFriday::Store::Redis, :store_config => { :pool => TestConfiguration::REDIS }
  controller_data "{:_actor => self.current_user.try(:email) || 'anonymous'}"

  middleware :users do
    ignore_if_controller 'self.is_a?(MockController) && ["create", "recent"].include?(params[:action])'
  end
  CONFIG
  
  BLOCK_CONFIGURATION = <<-CONFIG
  token 'FOOF'
  queue RulesIO::GirlFridayQueue, :store => GirlFriday::Store::Redis, :store_config => { :pool => TestConfiguration::REDIS }
  controller_data lambda { {:_actor => self.current_user.try(:email) || 'anonymous'} }

  middleware :users do
    ignore_if_controller lambda { self.is_a?(MockController) && ["create", "recent"].include?(params[:action]) }
  end
  CONFIG
  
  PROC_CONFIGURATION = <<-CONFIG
  token 'FOOF'
  queue RulesIO::GirlFridayQueue, :store => GirlFriday::Store::Redis, :store_config => { :pool => TestConfiguration::REDIS }
  controller_data proc { {:_actor => self.current_user.try(:email) || 'anonymous'} }

  middleware :users do
    ignore_if_controller proc { self.is_a?(MockController) && ["create", "recent"].include?(params[:action]) }
  end
  CONFIG

  setup do
    Rails.stubs(:logger)
    Rails.stubs(:application).returns(stub(:config => stub(:filter_parameters => [])))
    @rc = RulesIO::RailsConfigurator.new
  end
  
  test "general configuration works" do
    rack_middleware, user_middleware = @rc.instance_eval do
      eval TestConfiguration::STRING_CONFIGURATION, binding, __FILE__, __LINE__
      a = RulesIO::Rack.new(APP,
        :webhook_url => @webhook_url,
        :disable_sending_events => @disable,
        :token => @token,
        :queue => @queue,
        :queue_options => @queue_options,
        :controller_data => @controller_data
      )
      b = RulesIO::Users.new(APP, @middlewares[:users].configuration)
      [a,b]
    end
    assert_not_nil @rc.middlewares
    assert_equal 'FOOF', rack_middleware.token
    assert_equal 'self.is_a?(MockController) && ["create", "recent"].include?(params[:action])', user_middleware.instance_variable_get(:@options)[:ignore_if_controller]
  end
  
  test "configuring blocks as strings works" do
    rack_middleware, user_middleware = @rc.instance_eval do
      eval TestConfiguration::STRING_CONFIGURATION, binding, __FILE__, __LINE__
      a = RulesIO::Rack.new(APP,
        :webhook_url => @webhook_url,
        :disable_sending_events => @disable,
        :token => @token,
        :queue => @queue,
        :queue_options => @queue_options,
        :controller_data => @controller_data
      )
      b = RulesIO::Users.new(APP, @middlewares[:users].configuration)
      [a,b]
    end
    
    assert @rc.middlewares[:users].configuration[:ignore_if_controller].is_a? String
    assert_equal 'self.is_a?(MockController) && ["create", "recent"].include?(params[:action])', @rc.middlewares[:users].configuration[:ignore_if_controller]
    assert @rc.instance_variable_get(:@controller_data).is_a? String
    
    stub_controller_instance = stub(:current_user => stub(:email => 'email@example.com'), :params => {:action => 'update'})
    stub_controller_instance.expects(:is_a?).with(MockController).returns(true)
    env = {'action_controller.instance' => stub_controller_instance}
    assert_equal 'email@example.com', user_middleware.send(:current_actor, env)
    assert_equal false, user_middleware.send(:should_be_ignored, env)
  end
  
  test "configuring blocks as lambdas DOES NOT work" do
    rack_middleware, user_middleware = @rc.instance_eval do
      eval TestConfiguration::BLOCK_CONFIGURATION
      a = RulesIO::Rack.new(APP,
        :webhook_url => @webhook_url,
        :disable_sending_events => @disable,
        :token => @token,
        :queue => @queue,
        :queue_options => @queue_options,
        :controller_data => @controller_data
      )
      b = RulesIO::Users.new(APP, @middlewares[:users].configuration)
      [a,b]
    end
    
    assert @rc.middlewares[:users].configuration[:ignore_if_controller].is_a? Proc
    assert @rc.instance_variable_get(:@controller_data).is_a? Proc
    assert @rc.middlewares[:users].configuration[:ignore_if_controller].lambda?
    assert @rc.instance_variable_get(:@controller_data).lambda?
    
    stub_controller_instance = stub(:current_user => stub(:email => 'email@example.com'), :params => {:action => 'update'})
    # is never called, because a lambda doesn't work right with instance_eval
    stub_controller_instance.expects(:is_a?).never
    env = {'action_controller.instance' => stub_controller_instance}
    # returns nil, because lambda doesn't work right with instance_eval
    assert_equal nil, user_middleware.send(:current_actor, env)
    assert_equal false, user_middleware.send(:should_be_ignored, env)
  end
  
  test "configuring blocks as Procs works" do
    user_middleware = @rc.instance_eval do
      eval TestConfiguration::PROC_CONFIGURATION, binding, __FILE__, __LINE__
      RulesIO::Rack.new(APP,
        :webhook_url => @webhook_url,
        :disable_sending_events => @disable,
        :token => @token,
        :queue => @queue,
        :queue_options => @queue_options,
        :controller_data => @controller_data
      )
      RulesIO::Users.new(APP, @middlewares[:users].configuration)
    end
    
    assert @rc.middlewares[:users].configuration[:ignore_if_controller].is_a? Proc
    assert @rc.instance_variable_get(:@controller_data).is_a? Proc
    assert !@rc.middlewares[:users].configuration[:ignore_if_controller].lambda?
    assert !@rc.instance_variable_get(:@controller_data).lambda?
    
    stub_controller_instance = stub(:current_user => stub(:email => 'email@example.com'), :params => {:action => 'update'})
    stub_controller_instance.expects(:is_a?).with(MockController).returns(true)
    env = {'action_controller.instance' => stub_controller_instance}
    assert_equal 'email@example.com', user_middleware.send(:current_actor, env)
    assert_equal false, user_middleware.send(:should_be_ignored, env)
  end
end
