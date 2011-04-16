# Our assumptions with this seg:
#   - let(:prefix) is defined (e.g. 'coolio_')
#   - let(:method_name) is defined (e.g. 'coolio')
#   - #{prefix}running? method is defined in example group, it is true inside
#     #{method_name} call block, and false outside of it
#
shared_examples_for "EventedSpec adapter" do
  # Unfortunately, I know no other way to extract variables from let(...)
  prefix      = self.new.prefix
  method_name = self.new.method_name

  def loop_running?
    send("#{prefix}running?")
  end

  def loop(*args)
    send(method_name, *args) do
      yield
    end
  end

  before(:each) { loop_running?.should be_false }
  after(:each) { loop_running?.should be_false }

  describe "sanity check:" do
    it "we should not be in #{method_name} loop unless explicitly asked" do
      loop_running?.should be_false
    end
  end

  describe "#{method_name}" do
    it "should execute given block in the right scope" do
      @variable = 1
      loop do
        @variable.should == 1
        @variable = true
        done
      end
      @variable.should == true
    end

    it "should start default event loop and give control" do
      loop do
        loop_running?.should be_true
        done
      end
    end

    it "should stop the event loop afterwards" do
      loop do
        done
      end
      loop_running?.should be_false
    end

    it "should raise SpecTimeoutExceededError when #done is not issued" do
      expect {
        loop do
        end
      }.to raise_error(EventedSpec::SpecHelper::SpecTimeoutExceededError)
    end

    it "should propagate mismatched rspec expectations" do
      expect {
        loop do
          :fail.should == :win
        end
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end


  describe "#done" do
    it "should execute given block" do
      loop do
        done(0.05) do
          @variable = true
        end
      end
      @variable.should be_true
    end

    it "should cancel timeout" do
      expect {
        loop do
          done(0.2)
        end
      }.to_not raise_error
    end
  end

  describe "hooks" do
    context "before" do
      send("#{prefix}before") do
        @called_back = true
        loop_running?.should be_true
      end

      it "should run before example starts" do
        loop do
          @called_back.should be_true
          done
        end
      end
    end

    context "after" do
      send("#{prefix}after") do
        @called_back = true
        loop_running?.should be_true
      end

      it "should run after example finishes" do
        loop do
          @called_back.should be_false
          done
        end
        @called_back.should be_true
      end
    end
  end

  describe "#delayed" do
    it "should run an operation after certain amount of time" do
      loop(:spec_timeout => 3) do
        time = Time.now
        delayed(0.5) do
          (Time.now - time).should be_within(0.3).of(0.5)
          done
        end
      end
    end

    it "should preserve context" do
      loop(:spec_timeout => 3) do
        @instance_var = true
        delayed(0.1) do
          @instance_var.should be_true
          done
        end
      end
    end
  end


  describe "error handling" do
    it "bubbles failing expectations up to Rspec" do
      expect {
        loop do
          :this.should == :fail
        end
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      loop_running?.should be_false
    end
  end
end