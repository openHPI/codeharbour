# frozen_string_literal: true

require 'rails_helper'
require 'nokogiri'

RSpec.describe User do
  describe '#valid?' do
    let(:user) { create(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }

    context 'when avatar is not an image' do
      before do
        user.avatar.attach(io: Rails.root.join('spec/fixtures/files/avatar/profile.pdf').open, filename: 'profile.pdf', content_type: 'application/pdf')
      end

      it 'is not valid' do
        expect(user).not_to be_valid
      end

      it 'adds an error for avatar' do
        user.valid?
        expect(user.errors[:avatar]).to include(I18n.t('activerecord.errors.models.user.attributes.avatar.not_an_image'))
      end
    end

    context 'when avatar is an image' do
      before do
        user.avatar.attach(io: Rails.root.join('spec/fixtures/files/avatar/profile.png').open, filename: 'test.png', content_type: 'image/png')
      end

      it 'is valid' do
        expect(user).to be_valid
      end
    end

    context 'when avatar is larger than 10MB' do
      before do
        user.avatar.attach(io: Rails.root.join('spec/fixtures/files/avatar/large.png').open, filename: 'large.png', content_type: 'image/png')
      end

      it 'is not valid' do
        expect(user).not_to be_valid
      end

      it 'adds an error for avatar' do
        user.valid?
        expect(user.errors[:avatar]).to include(I18n.t('activerecord.errors.models.user.attributes.avatar.size_over_10_mb'))
      end
    end

    context 'when openai_api_key is present and valid' do
      before do
        allow(OpenAI::Client).to receive(:new).and_return(instance_double(OpenAI::Client, models: mock_models))
        user.openai_api_key = 'valid_key'
      end

      let(:mock_models) { instance_double(OpenAI::Models, list: {'data' => [{'id' => 'model-id'}]}) }

      it 'is valid' do
        expect(user).to be_valid
      end
    end

    context 'when openai_api_key is present and invalid' do
      before do
        allow(OpenAI::Client).to receive(:new).and_return(instance_double(OpenAI::Client, models: mock_models))
        allow(mock_models).to receive(:list).and_raise(OpenAI::Error)
        user.openai_api_key = 'invalid_key'
        user.valid?
      end

      let(:mock_models) { instance_double(OpenAI::Models) }

      it 'is not valid' do
        expect(user).not_to be_valid
      end

      it 'adds an error for invalid api key' do
        expect(user.errors[:base]).to include(I18n.t('activerecord.errors.models.user.invalid_api_key'))
      end
    end

    context 'when openai_api_key remains the same' do
      before do
        allow(OpenAI::Client).to receive(:new).and_return(instance_double(OpenAI::Client, models: mock_models))
        user.openai_api_key = 'same_key'
        user.save!
        user.valid?
      end

      let(:mock_models) { instance_double(OpenAI::Models, list: {'data' => [{'id' => 'model-id'}]}) }

      it 'does not trigger API validation' do
        expect(user.errors[:base]).not_to include(I18n.t('activerecord.errors.models.user.invalid_api_key'))
      end
    end
  end

  describe '#destroy' do
    subject(:destroy) { user.destroy }

    let!(:user) { create(:user) }

    it 'hashes email' do
      expect { destroy }.to change(user, :email).to Digest::MD5.hexdigest(user.email)
    end

    it { is_expected.to be true }

    it 'changes first_name to deleted' do
      expect { destroy }.to change(user, :first_name).to 'deleted'
    end

    it 'changes last_name to user' do
      expect { destroy }.to change(user, :last_name).to 'user'
    end

    it 'changes deleted to true' do
      expect { destroy }.to change(user, :deleted).to true
    end

    context 'when user is in a group' do
      before { group }

      let(:group) { create(:group, group_memberships:) }

      let(:group_memberships) { [build(:group_membership, :with_admin), build(:group_membership, user:)] }

      it { is_expected.to be true }

      it 'does not delete group' do
        expect { destroy }.not_to change(Group, :count)
      end

      it 'removes one group_membership' do
        expect { destroy }.to change { group.group_memberships.reload.size }.by(-1)
      end

      context 'when user is admin and only user in group' do
        let(:group_memberships) { build_list(:group_membership, 1, :with_admin, user:) }

        it 'deletes group' do
          expect { destroy }.to change(Group, :count).by(-1)
        end
      end

      context 'when another user is in the group, but does not have admin privileges' do
        let(:group_memberships) { [build(:group_membership, :with_admin, user:), build(:group_membership, created_at: 1.day.ago, user: new_admin), build(:group_membership, :with_applicant, created_at: 2.days.ago)] }
        let(:new_admin) { build(:user) }

        it 'does not delete group' do
          expect { destroy }.not_to change(Group, :count)
        end

        it 'promotes the oldest confirmed_member to admin' do
          expect { destroy }.to change { group.reload.group_membership_for(new_admin).role }.from('confirmed_member').to('admin')
        end

        context 'when the other user is also an admin' do
          let(:group_memberships) { [build(:group_membership, :with_admin, user:), build(:group_membership, :with_admin)] }

          it { is_expected.to be true }

          it 'does not delete group' do
            expect { destroy }.not_to change(Group, :count)
          end
        end
      end
    end

    context 'when user has a collection' do
      before { create(:collection, users:) }

      let(:users) { [user] }

      it 'deletes collection' do
        expect { destroy }.to change(Collection, :count).by(-1)
      end

      context 'when another user also has that collection' do
        let(:users) { [user, create(:user)] }

        it 'deletes collection' do
          expect { destroy }.not_to change(Collection, :count)
        end
      end
    end

    context 'when user has an exercise' do
      before { user.tasks << tasks }

      let(:tasks) { create(:task, user:) }

      it 'changes user of exercise to nil' do
        expect { destroy }.to change { tasks.reload.user }.from(user).to(nil)
      end
    end

    context 'when user has sent messages' do
      before { create(:message, sender: user) }

      it 'does not delete message' do
        expect { destroy }.not_to change(Message, :count)
      end

      context 'when message has type exercise', pending: 'messages and sharing permissions need to be reworked' do
        before do
          create(:message, sender: user, param_type: 'exercise', param_id: create(:task).id)
          create(:message, sender: user, param_type: 'group_requested', param_id: create(:group).id)
          create(:message, sender: user, param_type: 'collection', param_id: create(:collection).id)
        end

        it 'deletes message' do
          expect { destroy }.to change(Message, :count).by(-3)
        end
      end
    end

    context 'when user has identities' do
      before { create(:user_identity, user:) }

      it 'destroys identities' do
        expect { destroy }.to change(UserIdentity, :count).by(-1)
      end
    end
  end

  describe 'factories' do
    it 'has valid factory' do
      expect(build_stubbed(:user)).to be_valid
    end

    it 'requires first name' do
      expect(build_stubbed(:user, first_name: '')).not_to be_valid
    end

    it 'requires last name' do
      expect(build_stubbed(:user, last_name: '')).not_to be_valid
    end

    it 'requires email' do
      expect(build_stubbed(:user, email: '')).not_to be_valid
    end

    it 'uses the provided primary email for created users' do
      email = 'test@example.com'
      user = create(:user, email: 'test@example.com')
      expect(user.email).to eq email
    end

    it 'uses the provided primary email even for stubbed users' do
      email = 'test@example.com'
      user = build_stubbed(:user, email: 'test@example.com')
      expect(user.email).to eq email
    end

    context 'when two users are created' do
      let!(:user1) { create(:user) }
      let!(:user2) { create(:user) }

      it 'creates valid user1' do
        expect(user1).to be_valid
      end

      it 'creates valid user2' do
        expect(user2).to be_valid
      end

      it 'allows two users to be created without a primary email' do
        expect(user1.email).not_to eql user2.email
      end
    end
  end

  describe '#available_account_links' do
    subject(:available_account_links) { user.available_account_links }

    let(:user) { create(:user) }

    it { is_expected.to be_empty }

    context 'when an account_link exists' do
      let!(:account_link) { create(:account_link, user: another_user) }
      let(:another_user) { create(:user) }

      it { is_expected.to be_empty }

      context 'when user owns account_link' do
        let(:another_user) { user }

        it 'contains account_link' do
          expect(available_account_links).to include(account_link)
        end
      end

      context 'when account_link is shared' do
        before { create(:account_link_user, user:, account_link:) }

        it 'contains account_link' do
          expect(available_account_links).to include(account_link)
        end
      end
    end
  end
end
