RSpec.describe Celluloid::FSM, actor_system: :global do
  before :all do
    class TestMachine
      include Celluloid::FSM

      def initialize
        super
        @fired = false
      end

      state :callbacked do
        @fired = true
      end

      state :pre_done, :to => :done
      state :another, :done

      def fired?; @fired end
    end

    class DummyActor
      include Celluloid
    end

    class CustomDefaultMachine
      include Celluloid::FSM

      default_state :foobar
    end
  end

  subject { TestMachine.new }

  it "starts in the default state" do
    expect(subject.state).to eq(TestMachine.default_state)
  end

  it "transitions between states" do
    expect(subject.state).not_to be :done
    subject.transition :done
    expect(subject.state).to be :done
  end

  it "fires callbacks for states" do
    expect(subject).not_to be_fired
    subject.transition :callbacked
    expect(subject).to be_fired
  end

  it "allows custom default states" do
    expect(CustomDefaultMachine.new.state).to be :foobar
  end

  it "supports constraints on valid state transitions" do
    subject.transition :pre_done
    expect { subject.transition :another }.to raise_exception ArgumentError
  end

  it "transitions to states after a specified delay" do
    interval = Celluloid::TIMER_QUANTUM * 10

    subject.attach DummyActor.new
    subject.transition :another
    subject.transition :done, :delay => interval

    expect(subject.state).to be :another
    sleep interval + Celluloid::TIMER_QUANTUM

    expect(subject.state).to be :done
  end

  it "cancels delayed state transitions if another transition is made" do
    interval = Celluloid::TIMER_QUANTUM * 10

    subject.attach DummyActor.new
    subject.transition :another
    subject.transition :done, :delay => interval

    expect(subject.state).to be :another
    subject.transition :pre_done
    sleep interval + Celluloid::TIMER_QUANTUM

    expect(subject.state).to be :pre_done
  end

  context "actor is not set" do
    context "transition is delayed" do
      it "raises an unattached error" do
        expect { subject.transition :another, :delay => 100 } \
          .to raise_error(Celluloid::FSM::UnattachedError)
      end
    end
  end

  context "transitioning to an invalid state" do
    it "raises an argument error" do
      expect { subject.transition :invalid_state }.to raise_error(ArgumentError)
    end

    it "should not call transition! if the state is :default" do
      expect(subject).not_to receive :transition!
      subject.transition :default
    end
  end
end
