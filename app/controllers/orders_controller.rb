class OrdersController < ApplicationController
  def index
    scope = current_edition.orders.includes(:person).order(order_date: :desc)

    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(promo_code: params[:promo_code]) if params[:promo_code].present?
    scope = scope.where("order_date >= ?", params[:date_from]) if params[:date_from].present?
    scope = scope.where("order_date <= ?", params[:date_to]) if params[:date_to].present?

    @pagy, @orders = pagy(scope, items: 50)
  end

  def show
    @order = current_edition.orders
      .includes(registrations: [ :person, { registration_workshops: :workshop } ])
      .find(params[:id])
  end
end
