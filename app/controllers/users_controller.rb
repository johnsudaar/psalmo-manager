class UsersController < ApplicationController
  def index
    @users = User.order(:email)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to users_path, notice: "Utilisateur créé."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    user = User.find(params[:id])

    if user == current_user
      redirect_to users_path, alert: "Vous ne pouvez pas supprimer votre propre compte."
      return
    end

    user.destroy!
    redirect_to users_path, notice: "Utilisateur supprimé."
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
