import createPMRoute from "discourse/routes/build-private-messages-route";

export default createPMRoute(
  "sent",
  "private-messages-all-sent",
  null /* no message bus notifications */
);
