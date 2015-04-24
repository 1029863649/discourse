require 'spec_helper'
require 'post_creator'
require 'topic_subtype'

describe PostCreator do

  before do
    ActiveRecord::Base.observers.enable :all
  end

  let(:user) { Fabricate(:user) }

  context "new topic" do
    let(:category) { Fabricate(:category, user: user) }
    let(:topic) { Fabricate(:topic, user: user) }
    let(:basic_topic_params) { {title: "hello world topic", raw: "my name is fred", archetype_id: 1} }
    let(:image_sizes) { {'http://an.image.host/image.jpg' => {"width" => 111, "height" => 222}} }

    let(:creator) { PostCreator.new(user, basic_topic_params) }
    let(:creator_with_category) { PostCreator.new(user, basic_topic_params.merge(category: category.id )) }
    let(:creator_with_meta_data) { PostCreator.new(user, basic_topic_params.merge(meta_data: {hello: "world"} )) }
    let(:creator_with_image_sizes) { PostCreator.new(user, basic_topic_params.merge(image_sizes: image_sizes)) }

    it "can be created with auto tracking disabled" do
      p = PostCreator.create(user, basic_topic_params.merge(auto_track: false))
      # must be 0 otherwise it will think we read the topic which is clearly untrue
      expect(TopicUser.where(user_id: p.user_id, topic_id: p.topic_id).count).to eq(0)
    end

    it "ensures the user can create the topic" do
      Guardian.any_instance.expects(:can_create?).with(Topic,nil).returns(false)
      expect { creator.create }.to raise_error(Discourse::InvalidAccess)
    end


    context "invalid title" do

      let(:creator_invalid_title) { PostCreator.new(user, basic_topic_params.merge(title: 'a')) }

      it "has errors" do
        creator_invalid_title.create
        expect(creator_invalid_title.errors).to be_present
      end

    end

    context "invalid raw" do

      let(:creator_invalid_raw) { PostCreator.new(user, basic_topic_params.merge(raw: '')) }

      it "has errors" do
        creator_invalid_raw.create
        expect(creator_invalid_raw.errors).to be_present
      end

    end

    context "success" do

      it "doesn't return true for spam" do
        creator.create
        expect(creator.spam?).to eq(false)
      end

      it "triggers extensibility events" do
        DiscourseEvent.expects(:trigger).with(:before_create_post, anything).once
        DiscourseEvent.expects(:trigger).with(:validate_post, anything).once
        DiscourseEvent.expects(:trigger).with(:topic_created, anything, anything, user).once
        DiscourseEvent.expects(:trigger).with(:post_created, anything, anything, user).once
        creator.create
      end

      it "does not notify on system messages" do
        admin = Fabricate(:admin)
        messages = DiscourseBus.track_publish do
          p = PostCreator.create(admin, basic_topic_params.merge(post_type: Post.types[:moderator_action]))
          PostCreator.create(admin, basic_topic_params.merge(topic_id: p.topic_id, post_type: Post.types[:moderator_action]))
        end
        # don't notify on system messages they introduce too much noise
        channels = messages.map(&:channel)
        expect(channels.find{|s| s =~ /unread/}).to eq(nil)
        expect(channels.find{|s| s =~ /new/}).to eq(nil)
      end

      it "generates the correct messages for a secure topic" do

        admin = Fabricate(:admin)

        cat = Fabricate(:category)
        cat.set_permissions(:admins => :full)
        cat.save

        created_post = nil
        reply = nil

        messages = DiscourseBus.track_publish do
          created_post = PostCreator.new(admin, basic_topic_params.merge(category: cat.id)).create
          reply = PostCreator.new(admin, raw: "this is my test reply 123 testing", topic_id: created_post.topic_id).create
        end


        # 2 for topic, one to notify of new topic another for tracking state
        expect(messages.map{|m| m.channel}.sort).to eq([ "/new",
                                                     "/users/#{admin.username}",
                                                     "/users/#{admin.username}",
                                                     "/unread/#{admin.id}",
                                                     "/unread/#{admin.id}",
                                                     "/latest",
                                                     "/latest",
                                                     "/topic/#{created_post.topic_id}",
                                                     "/topic/#{created_post.topic_id}"
                                                   ].sort)
        admin_ids = [Group[:admins].id]

        expect(messages.any?{|m| m.group_ids != admin_ids && m.user_ids != [admin.id]}).to eq(false)
      end

      it 'generates the correct messages for a normal topic' do

        p = nil
        messages = DiscourseBus.track_publish do
          p = creator.create
        end

        latest = messages.find{|m| m.channel == "/latest"}
        expect(latest).not_to eq(nil)

        latest = messages.find{|m| m.channel == "/new"}
        expect(latest).not_to eq(nil)

        read = messages.find{|m| m.channel == "/unread/#{p.user_id}"}
        expect(read).not_to eq(nil)

        user_action = messages.find{|m| m.channel == "/users/#{p.user.username}"}
        expect(user_action).not_to eq(nil)

        expect(messages.length).to eq(5)
      end

      it 'extracts links from the post' do
        TopicLink.expects(:extract_from).with(instance_of(Post))
        creator.create
      end

      it 'queues up post processing job when saved' do
        Jobs.expects(:enqueue).with(:feature_topic_users, has_key(:topic_id))
        Jobs.expects(:enqueue).with(:process_post, has_key(:post_id))
        Jobs.expects(:enqueue).with(:post_alert, has_key(:post_id))
        Jobs.expects(:enqueue).with(:notify_mailing_list_subscribers, has_key(:post_id))
        creator.create
      end

      it 'passes the invalidate_oneboxes along to the job if present' do
        Jobs.stubs(:enqueue).with(:feature_topic_users, has_key(:topic_id))
        Jobs.expects(:enqueue).with(:notify_mailing_list_subscribers, has_key(:post_id))
        Jobs.expects(:enqueue).with(:post_alert, has_key(:post_id))
        Jobs.expects(:enqueue).with(:process_post, has_key(:invalidate_oneboxes))
        creator.opts[:invalidate_oneboxes] = true
        creator.create
      end

      it 'passes the image_sizes along to the job if present' do
        Jobs.stubs(:enqueue).with(:feature_topic_users, has_key(:topic_id))
        Jobs.expects(:enqueue).with(:notify_mailing_list_subscribers, has_key(:post_id))
        Jobs.expects(:enqueue).with(:post_alert, has_key(:post_id))
        Jobs.expects(:enqueue).with(:process_post, has_key(:image_sizes))
        creator.opts[:image_sizes] = {'http://an.image.host/image.jpg' => {'width' => 17, 'height' => 31}}
        creator.create
      end

      it 'assigns a category when supplied' do
        expect(creator_with_category.create.topic.category).to eq(category)
      end

      it 'adds  meta data from the post' do
        expect(creator_with_meta_data.create.topic.meta_data['hello']).to eq('world')
      end

      it 'passes the image sizes through' do
        Post.any_instance.expects(:image_sizes=).with(image_sizes)
        creator_with_image_sizes.create
      end

      it 'increases topic response counts' do
        first_post = creator.create

        # ensure topic user is correct
        topic_user = first_post.user.topic_users.find_by(topic_id: first_post.topic_id)
        expect(topic_user).to be_present
        expect(topic_user).to be_posted
        expect(topic_user.last_read_post_number).to eq(first_post.post_number)
        expect(topic_user.highest_seen_post_number).to eq(first_post.post_number)

        user2 = Fabricate(:coding_horror)
        expect(user2.user_stat.topic_reply_count).to eq(0)

        expect(first_post.user.user_stat.reload.topic_reply_count).to eq(0)

        PostCreator.new(user2, topic_id: first_post.topic_id, raw: "this is my test post 123").create

        expect(first_post.user.user_stat.reload.topic_reply_count).to eq(0)

        expect(user2.user_stat.reload.topic_reply_count).to eq(1)
      end

      it 'sets topic excerpt if first post, but not second post' do
        first_post = creator.create
        topic = first_post.topic.reload
        expect(topic.excerpt).to be_present
        expect {
          PostCreator.new(first_post.user, topic_id: first_post.topic_id, raw: "this is the second post").create
          topic.reload
        }.to_not change { topic.excerpt }
      end

      describe "topic's auto close" do

        it "doesn't update topic's auto close when it's not based on last post" do
          auto_close_time = 1.day.from_now
          topic = Fabricate(:topic, auto_close_at: auto_close_time, auto_close_hours: 12)

          PostCreator.new(topic.user, topic_id: topic.id, raw: "this is a second post").create
          topic.reload

          expect(topic.auto_close_at).to be_within(1.second).of(auto_close_time)
        end

        it "updates topic's auto close date when it's based on last post" do
          auto_close_time = 1.day.from_now
          topic = Fabricate(:topic, auto_close_at: auto_close_time, auto_close_hours: 12, auto_close_based_on_last_post: true)

          PostCreator.new(topic.user, topic_id: topic.id, raw: "this is a second post").create
          topic.reload

          expect(topic.auto_close_at).not_to be_within(1.second).of(auto_close_time)
        end

      end

    end

    context 'when auto-close param is given' do
      it 'ensures the user can auto-close the topic, but ignores auto-close param silently' do
        Guardian.any_instance.stubs(:can_moderate?).returns(false)
        post = PostCreator.new(user, basic_topic_params.merge(auto_close_time: 2)).create
        expect(post.topic.auto_close_at).to eq(nil)
      end
    end
  end

  context 'uniqueness' do

    let!(:topic) { Fabricate(:topic, user: user) }
    let(:basic_topic_params) { { raw: 'test reply', topic_id: topic.id, reply_to_post_number: 4} }
    let(:creator) { PostCreator.new(user, basic_topic_params) }

    context "disabled" do
      before do
        SiteSetting.unique_posts_mins = 0
        creator.create
      end

      it "returns true for another post with the same content" do
        new_creator = PostCreator.new(user, basic_topic_params)
        expect(new_creator.create).to be_present
      end
    end

    context 'enabled' do
      let(:new_post_creator) { PostCreator.new(user, basic_topic_params) }

      before do
        SiteSetting.unique_posts_mins = 10
      end

      it "fails for dupe post accross topic" do
        first = create_post
        second = create_post

        dupe = "hello 123 test #{SecureRandom.hex}"

        response_1 = create_post(raw: dupe, user: first.user, topic_id: first.topic_id)
        response_2 = create_post(raw: dupe, user: first.user, topic_id: second.topic_id)

        expect(response_1.errors.count).to eq(0)
        expect(response_2.errors.count).to eq(1)
      end

      it "returns blank for another post with the same content" do
        creator.create
        new_post_creator.create
        expect(new_post_creator.errors).to be_present
      end

      it "returns a post for admins" do
        creator.create
        user.admin = true
        new_post_creator.create
        expect(new_post_creator.errors).to be_blank
      end

      it "returns a post for moderators" do
        creator.create
        user.moderator = true
        new_post_creator.create
        expect(new_post_creator.errors).to be_blank
      end
    end

  end


  context "host spam" do

    let!(:topic) { Fabricate(:topic, user: user) }
    let(:basic_topic_params) { { raw: 'test reply', topic_id: topic.id, reply_to_post_number: 4} }
    let(:creator) { PostCreator.new(user, basic_topic_params) }

    before do
      Post.any_instance.expects(:has_host_spam?).returns(true)
    end

    it "does not create the post" do
      GroupMessage.stubs(:create)
      post = creator.create

      expect(creator.errors).to be_present
      expect(creator.spam?).to eq(true)
    end

    it "sends a message to moderators" do
      GroupMessage.expects(:create).with do |group_name, msg_type, params|
        group_name == Group[:moderators].name and msg_type == :spam_post_blocked and params[:user].id == user.id
      end
      creator.create
    end

  end

  # more integration testing ... maximise our testing
  context 'existing topic' do
    let!(:topic) { Fabricate(:topic, user: user) }
    let(:creator) { PostCreator.new(user, raw: 'test reply', topic_id: topic.id, reply_to_post_number: 4) }

    it 'ensures the user can create the post' do
      Guardian.any_instance.expects(:can_create?).with(Post, topic).returns(false)
      post = creator.create
      expect(post).to be_blank
      expect(creator.errors.count).to eq 1
      expect(creator.errors.messages[:base][0]).to match I18n.t(:topic_not_found)
    end

    context 'success' do
      it 'create correctly' do
        post = creator.create
        expect(Post.count).to eq(1)
        expect(Topic.count).to eq(1)
        expect(post.reply_to_post_number).to eq(4)
      end

    end

  end

  context 'closed topic' do
    let!(:topic) { Fabricate(:topic, user: user, closed: true) }
    let(:creator) { PostCreator.new(user, raw: 'test reply', topic_id: topic.id, reply_to_post_number: 4) }

    it 'responds with an error message' do
      post = creator.create
      expect(post).to be_blank
      expect(creator.errors.count).to eq 1
      expect(creator.errors.messages[:base][0]).to match I18n.t(:topic_not_found)
    end
  end

  context 'missing topic' do
    let!(:topic) { Fabricate(:topic, user: user, deleted_at: 5.minutes.ago) }
    let(:creator) { PostCreator.new(user, raw: 'test reply', topic_id: topic.id, reply_to_post_number: 4) }

    it 'responds with an error message' do
      post = creator.create
      expect(post).to be_blank
      expect(creator.errors.count).to eq 1
      expect(creator.errors.messages[:base][0]).to match I18n.t(:topic_not_found)
    end
  end

  context "cooking options" do
    let(:raw) { "this is my awesome message body hello world" }

    it "passes the cooking options through correctly" do
      creator = PostCreator.new(user,
                                title: 'hi there welcome to my topic',
                                raw: raw,
                                cooking_options: { traditional_markdown_linebreaks: true })

      Post.any_instance.expects(:cook).with(raw, has_key(:traditional_markdown_linebreaks)).returns(raw)
      creator.create
    end
  end

  # integration test ... minimise db work
  context 'private message' do
    let(:target_user1) { Fabricate(:coding_horror) }
    let(:target_user2) { Fabricate(:moderator) }
    let(:unrelated) { Fabricate(:user) }
    let(:post) do
      PostCreator.create(user, title: 'hi there welcome to my topic',
                               raw: "this is my awesome message @#{unrelated.username_lower}",
                               archetype: Archetype.private_message,
                               target_usernames: [target_user1.username, target_user2.username].join(','),
                               category: 1)
    end

    it 'acts correctly' do
      # It's not a warning
      expect(post.topic.warning).to be_blank

      expect(post.topic.archetype).to eq(Archetype.private_message)
      expect(post.topic.subtype).to eq(TopicSubtype.user_to_user)
      expect(post.topic.topic_allowed_users.count).to eq(3)

      # PMs can't have a category
      expect(post.topic.category).to eq(nil)

      # does not notify an unrelated user
      expect(unrelated.notifications.count).to eq(0)
      expect(post.topic.subtype).to eq(TopicSubtype.user_to_user)

      # if an admin replies they should be added to the allowed user list
      admin = Fabricate(:admin)
      PostCreator.create(admin, raw: 'hi there welcome topic, I am a mod',
                         topic_id: post.topic_id)

      post.topic.reload
      expect(post.topic.topic_allowed_users.where(user_id: admin.id).count).to eq(1)
    end
  end

  context "warnings" do
    let(:target_user1) { Fabricate(:coding_horror) }
    let(:target_user2) { Fabricate(:moderator) }
    let(:base_args) do
      { title: 'you need a warning buddy!',
        raw: "you did something bad and I'm telling you about it!",
        is_warning: true,
        target_usernames: target_user1.username,
        category: 1 }
    end

    it "works as expected" do
      # Invalid archetype
      creator = PostCreator.new(user, base_args)
      creator.create
      expect(creator.errors).to be_present

      # Too many users
      creator = PostCreator.new(user, base_args.merge(archetype: Archetype.private_message,
                                                      target_usernames: [target_user1.username, target_user2.username].join(',')))
      creator.create
      expect(creator.errors).to be_present

      # Success
      creator = PostCreator.new(user, base_args.merge(archetype: Archetype.private_message))
      post = creator.create
      expect(creator.errors).to be_blank

      topic = post.topic
      expect(topic).to be_present
      expect(topic.warning).to be_present
      expect(topic.subtype).to eq(TopicSubtype.moderator_warning)
      expect(topic.warning.user).to eq(target_user1)
      expect(topic.warning.created_by).to eq(user)
      expect(target_user1.warnings.count).to eq(1)
    end
  end

  context 'private message to group' do
    let(:target_user1) { Fabricate(:coding_horror) }
    let(:target_user2) { Fabricate(:moderator) }
    let(:group) do
      g = Fabricate.build(:group)
      g.add(target_user1)
      g.add(target_user2)
      g.save
      g
    end
    let(:unrelated) { Fabricate(:user) }
    let(:post) do
      PostCreator.create(user, title: 'hi there welcome to my topic',
                               raw: "this is my awesome message @#{unrelated.username_lower}",
                               archetype: Archetype.private_message,
                               target_group_names: group.name)
    end

    it 'acts correctly' do
      expect(post.topic.archetype).to eq(Archetype.private_message)
      expect(post.topic.topic_allowed_users.count).to eq(1)
      expect(post.topic.topic_allowed_groups.count).to eq(1)

      # does not notify an unrelated user
      expect(unrelated.notifications.count).to eq(0)
      expect(post.topic.subtype).to eq(TopicSubtype.user_to_user)

      expect(target_user1.notifications.count).to eq(1)
      expect(target_user2.notifications.count).to eq(1)
    end
  end

  context 'setting created_at' do
    created_at = 1.week.ago
    let(:topic) do
      PostCreator.create(user,
                         raw: 'This is very interesting test post content',
                         title: 'This is a very interesting test post title',
                         created_at: created_at)
    end

    let(:post) do
      PostCreator.create(user,
                         raw: 'This is very interesting test post content',
                         topic_id: Topic.last,
                         created_at: created_at)
    end

    it 'acts correctly' do
      expect(topic.created_at).to be_within(10.seconds).of(created_at)
      expect(post.created_at).to be_within(10.seconds).of(created_at)
    end
  end

  context 'disable validations' do
    it 'can save a post' do
      creator = PostCreator.new(user, raw: 'q', title: 'q', skip_validations: true)
      creator.create
      expect(creator.errors).to be_blank
    end
  end

  describe "word_count" do
    it "has a word count" do
      creator = PostCreator.new(user, title: 'some inspired poetry for a rainy day', raw: 'mary had a little lamb, little lamb, little lamb. mary had a little lamb')
      post = creator.create
      expect(post.word_count).to eq(14)

      post.topic.reload
      expect(post.topic.word_count).to eq(14)
    end
  end

  describe "embed_url" do

    let(:embed_url) { "http://eviltrout.com/stupid-url" }

    it "creates the topic_embed record" do
      creator = PostCreator.new(user,
                                embed_url: embed_url,
                                title: 'Reviews of Science Ovens',
                                raw: 'Did you know that you can use microwaves to cook your dinner? Science!')
      creator.create
      expect(TopicEmbed.where(embed_url: embed_url).exists?).to eq(true)
    end
  end

  describe "read credit for creator" do
    it "should give credit to creator" do
      post = create_post
      expect(PostTiming.find_by(topic_id: post.topic_id,
                         post_number: post.post_number,
                         user_id: post.user_id).msecs).to be > 0

      expect(TopicUser.find_by(topic_id: post.topic_id,
                        user_id: post.user_id).last_read_post_number).to eq(1)
    end
  end

  describe "suspended users" do
    it "does not allow suspended users to create topics" do
      user = Fabricate(:user, suspended_at: 1.month.ago, suspended_till: 1.month.from_now)

      creator = PostCreator.new(user, {title: "my test title 123", raw: "I should not be allowed to post"} )
      creator.create
      expect(creator.errors.count).to be > 0
    end
  end

  it "doesn't strip starting whitespaces" do
    pc = PostCreator.new(user, { title: "testing whitespace stripping", raw: "    <-- whitespaces -->    " })
    post = pc.create
    expect(post.raw).to eq("    <-- whitespaces -->")
  end

  context "events" do
    let(:topic) { Fabricate(:topic, user: user) }

    before do
      @posts_created = 0
      @topics_created = 0

      @increase_posts = -> (post, opts, user) { @posts_created += 1 }
      @increase_topics = -> (topic, opts, user) { @topics_created += 1 }
      DiscourseEvent.on(:post_created, &@increase_posts)
      DiscourseEvent.on(:topic_created, &@increase_topics)
    end

    after do
      DiscourseEvent.off(:post_created, &@increase_posts)
      DiscourseEvent.off(:topic_created, &@increase_topics)
    end

    it "fires boths event when creating a topic" do
      pc = PostCreator.new(user, raw: 'this is the new content for my topic', title: 'this is my new topic title')
      post = pc.create
      expect(@posts_created).to eq(1)
      expect(@topics_created).to eq(1)
    end

    it "fires only the post event when creating a post" do
      pc = PostCreator.new(user, topic_id: topic.id, raw: 'this is the new content for my post')
      post = pc.create
      expect(@posts_created).to eq(1)
      expect(@topics_created).to eq(0)
    end
  end

end
