import { isEmpty } from "@ember/utils";
import { userPath } from "discourse/lib/url";
import Badge from "discourse/models/badge";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

const _additionalAttributes = [];

export function includeAttributes(...attributes) {
  attributes.forEach((a) => _additionalAttributes.push(a));
}

export function transformBasicPost(post) {
  // Note: it can be dangerous to not use `get` in Ember code, but this is significantly
  // faster and has tests to confirm it works. We only call `get` when the property is a CP
  const postAtts = {
    id: post.id,
    hidden: post.hidden,
    deleted: post.get("deleted"),
    deleted_at: post.deleted_at,
    user_deleted: post.user_deleted,
    isDeleted: post.deleted,
    deletedByAvatarTemplate: null,
    deletedByUsername: null,
    primary_group_name: post.primary_group_name,
    flair_name: post.flair_name,
    flair_url: post.flair_url,
    flair_bg_color: post.flair_bg_color,
    flair_color: post.flair_color,
    flair_group_id: post.flair_group_id,
    wiki: post.wiki,
    lastWikiEdit: post.last_wiki_edit,
    firstPost: post.post_number === 1,
    post_number: post.post_number,
    cooked: post.cooked,
    via_email: post.via_email,
    isAutoGenerated: post.is_auto_generated,
    user_id: post.user_id,
    usernameUrl: userPath(post.username),
    username: post.username,
    badgesGranted:
      post.badges_granted &&
      post.badges_granted.map((badge) => Badge.createFromJson(badge)[0]),
    avatar_template: post.avatar_template,
    bookmarked: post.bookmarked,
    bookmarkReminderAt: post.bookmark_reminder_at,
    bookmarkName: post.bookmark_name,
    yours: post.yours,
    shareUrl: post.get("shareUrl"),
    staff: post.staff,
    admin: post.admin,
    moderator: post.moderator,
    groupModerator: post.group_moderator,
    new_user: post.trust_level === 0,
    name: post.name,
    user_title: post.user_title,
    title_is_group: post.title_is_group,
    created_at: post.created_at,
    updated_at: post.updated_at,
    canDelete: post.can_delete,
    canPermanentlyDelete: false,
    showFlagDelete: false,
    canRecover: post.can_recover,
    canSeeHiddenPost: post.can_see_hidden_post,
    canEdit: post.can_edit,
    canFlag: !post.get("topic.deleted") && !isEmpty(post.get("flagsAvailable")),
    canReviewTopic: false,
    reviewableId: post.reviewable_id,
    reviewableScoreCount: post.reviewable_score_count,
    reviewableScorePendingCount: post.reviewable_score_pending_count,
    version: post.version,
    canRecoverTopic: false,
    canDeleteTopic: false,
    canViewEditHistory: post.can_view_edit_history,
    canWiki: post.can_wiki,
    showLike: false,
    liked: false,
    canToggleLike: false,
    likeCount: false,
    actionsSummary: null,
    read: post.read,
    replyToUsername: null,
    replyToName: null,
    replyToAvatarTemplate: null,
    reply_to_post_number: post.reply_to_post_number,
    cooked_hidden: !!post.cooked_hidden,
    expandablePost: false,
    replyCount: post.reply_count,
    locked: post.locked,
    userCustomFields: post.user_custom_fields,
    readCount: post.readers_count,
    canPublishPage: false,
    trustLevel: post.trust_level,
    userSuspended: post.user_suspended,
  };

  _additionalAttributes.forEach((a) => (postAtts[a] = post[a]));

  return postAtts;
}

export default function transformPost(
  currentUser,
  site,
  post,
  prevPost,
  nextPost
) {
  // Note: it can be dangerous to not use `get` in Ember code, but this is significantly
  // faster and has tests to confirm it works. We only call `get` when the property is a CP
  const postType = post.post_type;
  const postTypes = site.post_types;
  const topic = post.topic;
  const details = topic.get("details");
  const filteredUpwardsPostID = topic.get("postStream.filterUpwardsPostID");
  const filteredRepliesPostNumber = topic.get(
    "postStream.filterRepliesToPostNumber"
  );

  const postAtts = transformBasicPost(post);

  const createdBy = details.created_by || {};

  postAtts.topic = topic;
  postAtts.topicId = topic.id;
  postAtts.topicOwner = createdBy.id === post.user_id;
  postAtts.topicCreatedById = createdBy.id;
  postAtts.post_type = postType;
  postAtts.via_email = post.via_email;
  postAtts.isAutoGenerated = post.is_auto_generated;
  postAtts.isModeratorAction = post.isModeratorAction;
  postAtts.isWhisper = post.isWhisper;
  postAtts.isSmallAction =
    postType === postTypes.small_action || post.action_code === "split_topic";
  postAtts.canBookmark = !!currentUser;
  postAtts.canManage = post.canManage;
  postAtts.canViewRawEmail = currentUser && currentUser.can_view_raw_email;
  postAtts.canArchiveTopic = !!details.can_archive_topic;
  postAtts.canCloseTopic = !!details.can_close_topic;
  postAtts.canSplitMergeTopic = !!details.can_split_merge_topic;
  postAtts.canEditStaffNotes = post.canEditStaffNotes;
  postAtts.canReplyAsNewTopic = !!details.can_reply_as_new_topic;
  postAtts.canReviewTopic = !!details.can_review_topic;
  postAtts.canPublishPage = post.canPublishPage;
  postAtts.isWarning = topic.is_warning;
  postAtts.links = post.get("internalLinks");

  // on the glimmer post menu this logic was implemented on the PostMenu component as it depends on
  // two post object instances
  // if you change the logic replyDirectlyBelow here, while the widget post menu is still around, please
  // be sure to also update the logic on the Glimmer PostMenu component
  postAtts.replyDirectlyBelow =
    nextPost &&
    nextPost.reply_to_post_number === post.post_number &&
    post.post_number !== filteredRepliesPostNumber;

  postAtts.replyDirectlyAbove =
    prevPost &&
    post.id !== filteredUpwardsPostID &&
    post.reply_to_post_number === prevPost.post_number;
  postAtts.linkCounts = post.link_counts;
  postAtts.actionCode = post.action_code;
  postAtts.actionCodeWho = post.action_code_who;
  postAtts.actionCodePath = getURL(post.action_code_path || `/t/${topic.id}`);
  postAtts.topicUrl = topic.get("url");
  postAtts.isSaving = post.isSaving;
  postAtts.staged = post.staged;
  postAtts.user = post.user;

  if (post.notice) {
    postAtts.notice = post.notice;
    if (postAtts.notice.type === "returning_user") {
      postAtts.notice.lastPostedAt = new Date(post.notice.last_posted_at);
    }
  }

  if (post.post_number === 1 && topic.requested_group_name) {
    postAtts.requestedGroupName = topic.requested_group_name;
  }

  if (postAtts.isDeleted) {
    postAtts.deletedByAvatarTemplate = post.get(
      "postDeletedBy.avatar_template"
    );
    postAtts.deletedByUsername = post.get("postDeletedBy.username");
  }

  const replyToUser = post.get("reply_to_user");
  if (replyToUser) {
    postAtts.replyToUsername = replyToUser.username;
    postAtts.replyToName = replyToUser.name;
    postAtts.replyToAvatarTemplate = replyToUser.avatar_template;
  }

  if (post.actions_summary) {
    postAtts.actionsSummary = post.actions_summary
      .filter((a) => {
        return a.actionType.name_key !== "like" && a.acted;
      })
      .map((a) => {
        const action = a.actionType.name_key;

        return {
          id: a.id,
          postId: post.id,
          action,
          canUndo: a.can_undo,
          description: I18n.t(`post.actions.by_you.${action}`, {
            defaultValue: I18n.t(`post.actions.by_you.custom`, {
              custom: a.actionType.name,
            }),
          }),
        };
      });
  }

  postAtts.liked = post.liked;

  const likeAction = post.likeAction;
  if (likeAction) {
    postAtts.canToggleLike = likeAction.get("canToggle");
    postAtts.showLike = postAtts.liked || postAtts.canToggleLike;
    postAtts.likeCount = likeAction.count;
  } else if (
    !currentUser ||
    (topic.archived && topic.user_id !== currentUser.id)
  ) {
    postAtts.showLike = true;
  }

  postAtts.canDelete = post.canDelete;
  postAtts.canDeleteTopic = post.canDeleteTopic;
  postAtts.canPermanentlyDelete = post.canPermanentlyDelete;
  postAtts.canRecover = post.canRecover;
  postAtts.canRecoverTopic = post.canRecoverTopic;

  if (postAtts.post_number === 1) {
    postAtts.expandablePost = topic.expandable_first_post;

    // Show a "Flag to delete" message if not staff and you can't
    // otherwise delete it.
    postAtts.showFlagDelete =
      !postAtts.canDelete &&
      postAtts.yours &&
      postAtts.canFlag &&
      currentUser &&
      !currentUser.staff;
  } else {
    postAtts.canDelete =
      postAtts.canDelete &&
      !post.deleted_at &&
      currentUser &&
      (currentUser.staff || !post.user_deleted);
  }

  _additionalAttributes.forEach((a) => (postAtts[a] = post[a]));

  return postAtts;
}
