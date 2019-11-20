# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CartsController, type: :controller do
  let(:user) { create(:user, cart: cart) }

  let(:valid_attributes) do
    {user: user}
  end

  let(:invalid_attributes) do
  end

  let(:valid_session) do
    {user_id: user.id}
  end
  let(:cart) { create(:cart) }

  describe 'GET #show' do
    it 'assigns the requested cart as @cart' do
      get :show, params: {id: cart.to_param}, session: valid_session
      expect(assigns(:cart)).to eq(cart)
    end
  end

  describe 'GET #my_cart' do
    let(:get_request) { get :my_cart, session: valid_session }

    it 'redirects to show' do
      get_request
      expect(response).to redirect_to(cart)
    end
  end

  describe 'GET #remove_exercise' do
    let!(:exercise) { create(:exercise, carts: [cart]) }
    let(:get_request) { get :remove_exercise, params: {id: cart.id, exercise: exercise.id}, session: valid_session }

    it 'removes exercise from cart' do
      expect { get_request }.to change(cart.reload.exercises, :count).by(-1)
    end
  end

  describe 'GET #remove_all' do
    let(:get_request) { get :remove_all, params: {id: cart.id}, session: valid_session }

    before { create_list(:exercise, 2, carts: [cart]) }

    it 'removes exercise from cart' do
      expect { get_request }.to change(cart.exercises, :count).by(-2)
    end
  end

  # fdescribe 'POST #push_cart' do
  #   let(:account_link) { create(:account_link, user: user) }

  #   let(:get_request) { post :push_cart, params: {id: cart.id, account_link: account_link.id}, session: valid_session }

  #   before { create_list(:exercise, 2, carts: [cart]) }

  #   it 'removes exercise from cart' do
  #     expect { get_request }.to change(cart.exercises, :count).by(-2)
  #   end
  # end

  describe 'GET #download_all' do
    let(:get_request) { get :download_all, params: {id: cart.id}, session: valid_session }
    let(:zip) { instance_double('StringIO', string: 'dummy') }
    let!(:exercises) { create_list(:exercise, 2, carts: [cart]) }

    before { allow(ProformaService::ExportTasks).to receive(:call).with(exercises: cart.reload.exercises).and_return(zip) }

    it do
      get_request
      expect(ProformaService::ExportTasks).to have_received(:call)
    end

    it 'updates download count' do
      expect { get_request }.to change { exercises.first.reload.downloads }.by(1)
    end

    it 'sends the correct data' do
      get_request
      expect(response.body).to eql 'dummy'
    end

    it 'sets the correct Content-Type header' do
      get_request
      expect(response.header['Content-Type']).to eql 'application/zip'
    end

    it 'sets the correct Content-Disposition header' do
      get_request
      expect(response.header['Content-Disposition'])
        .to eql "attachment; filename=\"#{I18n.t('controllers.carts.zip_filename', date: Time.zone.today.strftime)}\""
    end
  end
end
