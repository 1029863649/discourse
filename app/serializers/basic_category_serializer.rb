class BasicCategorySerializer < ApplicationSerializer

  attributes :id,
             :name,
             :color,
             :text_color,
             :slug,
             :topic_count,
             :description,
             :topic_url,
             :hotness,
             :read_restricted,
             :permission,
             :parent_category_id

  def filter(keys)
    keys -= [ :parent_category_id ] unless parent_category_id
    keys
  end

end
