class Lp::PostsController < PostsController
  def create
    resp = {errors:[], topic: nil, comment: nil}

    begin

      ActiveRecord::Base.connection.transaction do

        topic_post_params = {
          skip_validations: true,
          auto_track: false,
          title: params[:topic_title],
          raw: params[:topic_description],
        }

        topic_post_creator = PostCreator.new(current_user, topic_post_params)
        topic_post = topic_post_creator.create

        if topic_post_creator.errors.present?
          resp[:errors] << topic_post_creator.errors.full_messages
        else
          topic_post_serializer = PostSerializer.new(topic_post, scope: guardian, root: false)
          topic_post_serializer.topic_slug = topic_post.topic.slug
          resp[:topic] = topic_post_serializer
        end

        comment_post_params = {
          skip_validations: true,
          auto_track: false,
          raw: params[:comment],
          topic_id: topic_post.topic.id
        }

        comment_user = User.find_by_email(params[:email])
        comment_post_creator = PostCreator.new(comment_user, comment_post_params)
        comment_post = comment_post_creator.create

        if comment_post_creator.errors.present?
          resp[:errors] << comment_post_creator.errors.full_messages
        else
          comment_post_serializer = PostSerializer.new(comment_post, scope: guardian, root: false)
          resp[:comment] = comment_post_serializer
        end

      end

    rescue Exception => e
      resp[:errors] << {exception: "#{e.class} #{e.message}", backtrace: e.backtrace}
    end

    render json: MultiJson.dump(resp), status: resp[:errors].present? ? 422 : 200
  end
end
