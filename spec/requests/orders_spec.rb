require "rails_helper"

RSpec.describe "Orders", type: :request do
  let(:user)    { create(:user) }
  let(:edition) { create(:edition) }
  let(:order)   { create(:order, edition: edition) }

  before do
    sign_in user
    patch update_edition_session_path, params: { edition_id: edition.id }
  end

  describe "unauthenticated access" do
    before { sign_out user }

    it "redirects to sign-in for index" do
      get orders_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to sign-in for show" do
      get order_path(order)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /orders" do
    it "returns 200 and renders the page" do
      create(:order, edition: edition)
      get orders_path
      expect(response).to have_http_status(:ok)
    end

    it "filters by status" do
      create(:order, edition: edition, status: :cancelled)
      get orders_path, params: { status: "confirmed" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /orders/:id" do
    it "returns 200 and renders the page" do
      create(:registration, order: order, edition: edition)
      get order_path(order)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for an order from another edition" do
      other_edition = create(:edition, year: edition.year + 1)
      other_order   = create(:order, edition: other_edition)
      get order_path(other_order)
      expect(response).to have_http_status(:not_found)
    end
  end
end
