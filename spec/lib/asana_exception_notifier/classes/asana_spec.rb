# encoding:utf-8

require 'spec_helper'

describe ExceptionNotifier::AsanaNotifier do

  let(:options) { double('options') }

  before(:each) do
    allow(options).to receive(:symbolize_keys) { options }
    allow(options).to receive(:reject) { options }
    allow_any_instance_of(ExceptionNotifier::AsanaNotifier).to receive(:parse_options).and_return(true)
    @subject = ExceptionNotifier::AsanaNotifier.new(options)
  end

  describe '#initialize' do
    it 'creates a object' do
      expect(@subject.initial_options).to eq options
    end
  end


end
