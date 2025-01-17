# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'an unauthorized request' do
  it 'redirects to root' do
    expect(response).to redirect_to root_path
  end

  it 'displays an error message' do
    expect(flash[:alert]).to include I18n.t('common.errors.not_authorized')
  end
end
