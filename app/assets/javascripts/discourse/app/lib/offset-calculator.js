export function scrollTopFor(y) {
  return y - offsetCalculator();
}

export function minimumOffset() {
  const header = document.querySelector("header.d-header");
  const headerHeight = header.offsetHeight;
  return headerHeight;
}

export default function offsetCalculator() {
  const min = minimumOffset();

  // on mobile, just use the header
  if (document.querySelector("html").classList.contains("mobile-view"))
    return min;

  const windowHeight = window.innerWidth;
  const documentHeight = document.body.clientHeight;
  const topicBottomOffsetTop = document.getElementById("topic-bottom")
    .offsetTop;

  // the footer is bigger than the window, we can scroll down past the last post
  if (documentHeight - windowHeight > topicBottomOffsetTop) return min;

  const scrollTop = window.scrollTop;
  const visibleBottomHeight = scrollTop + windowHeight - topicBottomOffsetTop;

  if (visibleBottomHeight > 0) {
    const bottomHeight = documentHeight - topicBottomOffsetTop;
    const offset =
      ((windowHeight - bottomHeight) * visibleBottomHeight) / bottomHeight;
    return Math.max(min, offset);
  }

  return min;
}
