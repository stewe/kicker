require File.expand_path('../test_helper', __FILE__)

class Kicker
  module Utils
    public :will_execute_command, :did_execute_command
  end
end

describe "A Kicker instance, concerning its utility methods" do
  before do
    utils.stubs(:puts)
  end
  
  after do
    Kicker.silent = false
    Kicker::Growl.use = true
  end
  
  it "should print a log entry with timestamp" do
    now = Time.now
    Time.stubs(:now).returns(now)
    
    utils.expects(:puts).with("#{now.strftime('%H:%M:%S')}.#{now.usec.to_s[0,2]} | the message")
    utils.send(:log, 'the message')
  end
  
  it 'should print a log entry with no timestamp in quiet mode' do
    before = Kicker.quiet
    
    utils.expects(:puts).with('the message')
    
    Kicker.quiet = true
    utils.send(:log, 'the message')
    
    Kicker.quiet = before
  end
  
  it "logs that the command succeeded" do
    Kicker::Growl.use = false

    utils.stubs(:_execute).with do |status|
      status.output = "line 1\nline 2"
      status.exit_code = 0
    end
    utils.expects(:log).with('Executing: ls')
    utils.expects(:log).with('Success')
    utils.execute('ls')
  end

  it "logs that the command failed" do
    Kicker::Growl.use = false
    utils.stubs(:_execute).with do |status|
      status.output = "line 1\nline 2"
      status.exit_code = 123
    end
    utils.expects(:log).with('Executing: ls')
    utils.expects(:log).with('Failed (123)')
    utils.execute('ls')
  end

  it "should growl a change occurred and the output" do
    utils.stubs(:log)
    utils.stubs(:_execute).with do |status|
      status.output = "line 1\nline 2"
    end 
    Kicker::Growl.expects(:change_occured).with { |status| status.command == 'ls' }
    Kicker::Growl.expects(:result).with { |status| status.output == "line 1\nline 2" }
    utils.execute('ls')
  end
  
  it "should not growl that a change occured in silent mode" do
    Kicker.silent = true
    utils.stubs(:did_execute_command)
    
    utils.expects(:log)
    Kicker::Growl.expects(:change_occured).never
    utils.execute('ls')
  end
  
  it "should only log that is has succeeded in silent mode" do
    Kicker.silent = true
    Kicker::Growl.expects(:result).with { |status| status.output == "line 1\nline 2" }
    
    status = Kicker::Status.new('ls -l', 0, "line 1\nline 2")
    
    utils.expects(:log).with("Success")
    utils.did_execute_command(status)
  end
  
  it "should fully log that it has failed in silent mode" do
    Kicker.silent = true
    Kicker::Growl.expects(:result).with { |status| status.output == "line 1\nline 2" }
    
    utils.expects(:puts).with("\nline 1\nline 2\n\n")
    utils.expects(:log).with('Failed (123)')
    
    status = Kicker::Status.new('ls -l', 123, "line 1\nline 2")
    utils.did_execute_command(status)
  end

  it "should store the last executed command" do
    Kicker::Growl.use = false
    Kicker.silent = true
    utils.stubs(:log)
    
    utils.execute('date')
    utils.last_command.should == 'date'
  end
  
  it "calls the block given to execute and yields the status so the user can transform the output" do
    Kicker.silent = true
    Kicker::Growl.use = false

    utils.stubs(:_execute).with do |status|
      status.output = "line 1\nline 2"
      status.exit_code = 123
    end

    utils.expects(:log).with('Executing: ls -l')
    utils.expects(:puts).with("\nOhnoes!\n\n")
    utils.expects(:log).with('Failed (123)')

    utils.execute('ls -l') do |status|
      status.output = status.success? ? 'Done!' : 'Ohnoes!'
    end
  end
  
  private
  
  def utils
    Kicker::Utils
  end
end

describe "Kernel utility methods" do
  before do
    utils.stubs(:last_command_succeeded?).returns(true)
  end
  
  it "should forward log calls to the Kicker::Utils module" do
    utils.expects(:log).with('the message')
    log 'the message'
  end
  
  it "should forward execute calls to the Kicker::Utils module" do
    utils.expects(:execute).with('ls')
    execute 'ls'
  end
  
  it "should return the last_command" do
    utils.stubs(:last_command).returns('abcde')
    last_command.should == 'abcde'
  end
  
  private
  
  def utils
    Kicker::Utils
  end
end
