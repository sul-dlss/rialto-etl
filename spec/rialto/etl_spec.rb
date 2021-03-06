# frozen_string_literal: true

RSpec.describe Rialto::Etl do
  describe 'configuration' do
    it 'provides a configuration value for CAP token' do
      expect(Settings.cap.api_key).not_to be_empty
    end

    describe 'overriding values via environment variables' do
      let(:overridden_value) { 'dropthebeat' }

      before do
        ENV['SETTINGS__CAP__API_KEY'] = overridden_value
        Settings.reload!
      end

      it 'works as configured' do
        expect(Settings.cap.api_key).to eq overridden_value
      end
    end
  end
end
