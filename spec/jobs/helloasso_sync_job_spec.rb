require "rails_helper"

RSpec.describe HelloassoSyncJob, type: :job do
  let(:edition) { create(:edition) }

  describe "#perform" do
    it "calls Helloasso::SyncService with the edition" do
      sync_service = instance_double(Helloasso::SyncService, call: nil)
      allow(Helloasso::SyncService).to receive(:new).with(edition).and_return(sync_service)

      described_class.perform_now(edition.id)

      expect(sync_service).to have_received(:call)
    end

    it "re-raises errors so Sidekiq can retry" do
      allow(Helloasso::SyncService).to receive(:new).and_raise(RuntimeError, "API down")

      expect {
        described_class.perform_now(edition.id)
      }.to raise_error(RuntimeError, "API down")
    end

    it "raises ActiveRecord::RecordNotFound for an unknown edition_id" do
      expect {
        described_class.perform_now(-1)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
