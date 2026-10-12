# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Must do
  describe '.because' do
    it 'returns a present value without calling the block' do
      expect { |b| expect(described_class.because(1, &b)).to eq(1) }.not_to yield_control
    end

    it 'returns false as a present value' do
      expect(described_class.because(false) { 'unreachable' }).to be(false)
    end

    it 'raises Violation carrying the block message on nil' do
      expect { described_class.because(nil) { 'gate on login first' } }
        .to raise_error(Must::Violation, 'gate on login first')
    end
  end

  describe '.expect' do
    it 'returns a present value' do
      expect(described_class.expect('x')).to eq('x')
    end

    it 'raises Violation on nil' do
      expect { described_class.expect(nil) }.to raise_error(Must::Violation, 'expected a value, got nil')
    end
  end

  describe '.be_a' do
    it 'returns a value of the class' do
      expect(described_class.be_a(1, Integer)).to eq(1)
    end

    it 'raises Violation for a value of another class' do
      expect { described_class.be_a('1', Integer) }.to raise_error(Must::Violation, 'expected Integer, got String')
    end
  end

  it 'keeps Violation outside the application error hierarchy' do
    expect(Must::Violation.superclass).to eq(StandardError)
  end
end
