# frozen_string_literal: true

require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

RSpec.describe FileTypesController, type: :controller do
  # This should return the minimal set of attributes required to create a valid
  # FileType. As you add validations to FileType, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) do
    skip('Add a hash of attributes valid for your model')
  end

  let(:invalid_attributes) do
    skip('Add a hash of attributes invalid for your model')
  end

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # FileTypesController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe 'GET #index' do
    it 'assigns all file_types as @file_types' do
      file_type = FileType.create! valid_attributes
      get :index, params: {}, session: valid_session
      expect(assigns(:file_types)).to eq([file_type])
    end
  end

  describe 'GET #show' do
    it 'assigns the requested file_type as @file_type' do
      file_type = FileType.create! valid_attributes
      get :show, params: {id: file_type.to_param}, session: valid_session
      expect(assigns(:file_type)).to eq(file_type)
    end
  end

  describe 'GET #new' do
    it 'assigns a new file_type as @file_type' do
      get :new, params: {}, session: valid_session
      expect(assigns(:file_type)).to be_a_new(FileType)
    end
  end

  describe 'GET #edit' do
    it 'assigns the requested file_type as @file_type' do
      file_type = FileType.create! valid_attributes
      get :edit, params: {id: file_type.to_param}, session: valid_session
      expect(assigns(:file_type)).to eq(file_type)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new FileType' do
        expect do
          post :create, params: {file_type: valid_attributes}, session: valid_session
        end.to change(FileType, :count).by(1)
      end

      it 'assigns a newly created file_type as @file_type' do
        post :create, params: {file_type: valid_attributes}, session: valid_session
        expect(assigns(:file_type)).to be_a(FileType)
      end

      it 'persists @file_type' do
        post :create, params: {file_type: valid_attributes}, session: valid_session
        expect(assigns(:file_type)).to be_persisted
      end

      it 'redirects to the created file_type' do
        post :create, params: {file_type: valid_attributes}, session: valid_session
        expect(response).to redirect_to(FileType.last)
      end
    end

    context 'with invalid params' do
      it 'assigns a newly created but unsaved file_type as @file_type' do
        post :create, params: {file_type: invalid_attributes}, session: valid_session
        expect(assigns(:file_type)).to be_a_new(FileType)
      end

      it "re-renders the 'new' template" do
        post :create, params: {file_type: invalid_attributes}, session: valid_session
        expect(response).to render_template('new')
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      let(:new_attributes) do
        skip('Add a hash of attributes valid for your model')
      end

      it 'updates the requested file_type' do
        file_type = FileType.create! valid_attributes
        put :update, params: {id: file_type.to_param, file_type: new_attributes}, session: valid_session
        file_type.reload
        skip('Add assertions for updated state')
      end

      it 'assigns the requested file_type as @file_type' do
        file_type = FileType.create! valid_attributes
        put :update, params: {id: file_type.to_param, file_type: valid_attributes}, session: valid_session
        expect(assigns(:file_type)).to eq(file_type)
      end

      it 'redirects to the file_type' do
        file_type = FileType.create! valid_attributes
        put :update, params: {id: file_type.to_param, file_type: valid_attributes}, session: valid_session
        expect(response).to redirect_to(file_type)
      end
    end

    context 'with invalid params' do
      it 'assigns the file_type as @file_type' do
        file_type = FileType.create! valid_attributes
        put :update, params: {id: file_type.to_param, file_type: invalid_attributes}, session: valid_session
        expect(assigns(:file_type)).to eq(file_type)
      end

      it "re-renders the 'edit' template" do
        file_type = FileType.create! valid_attributes
        put :update, params: {id: file_type.to_param, file_type: invalid_attributes}, session: valid_session
        expect(response).to render_template('edit')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested file_type' do
      file_type = FileType.create! valid_attributes
      expect do
        delete :destroy, params: {id: file_type.to_param}, session: valid_session
      end.to change(FileType, :count).by(-1)
    end

    it 'redirects to the file_types list' do
      file_type = FileType.create! valid_attributes
      delete :destroy, params: {id: file_type.to_param}, session: valid_session
      expect(response).to redirect_to(file_types_url)
    end
  end
end
