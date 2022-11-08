# frozen_string_literal: true

class CategoryChannel < ChatChannel
  alias_attribute :category, :chatable

  delegate :read_restricted?, to: :category
  delegate :url, to: :chatable, prefix: true

  %i[category_channel? public_channel? chatable_has_custom_fields?].each do |name|
    define_method(name) { true }
  end

  def allowed_group_ids
    return if !read_restricted?

    staff_groups = Group::AUTO_GROUPS.slice(:staff, :moderators, :admins).values
    category.secure_group_ids.to_a.concat(staff_groups)
  end

  def title(_ = nil)
    name.presence || category.name
  end

  def ensure_slug
    return if title.blank?
    slug_title = self.title.strip

    if self.slug.present?
      # if we don't unescape it first we strip the % from the encoded version
      slug = SiteSetting.slug_generation_method == "encoded" ? CGI.unescape(self.slug) : self.slug
      self.slug = Slug.for(slug, "", method: :encoded)

      if self.slug.blank?
        errors.add(:slug, :invalid)
      elsif SiteSetting.slug_generation_method == "ascii" && !CGI.unescape(self.slug).ascii_only?
        errors.add(:slug, I18n.t("category_channel.errors.slug_contains_non_ascii_chars"))
      elsif duplicate_slug?
        errors.add(:slug, I18n.t("category_channel.errors.is_already_in_use"))
      end
    else
      # auto slug
      self.slug = Slug.for(slug_title, "")
      self.slug = "" if duplicate_slug?
    end
  end
end
