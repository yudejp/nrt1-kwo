// Official OpenCode 2.3.0 plugin API. Let the durable Go queue select another
// provider after a terminal rate rejection instead of sleeping inside the CLI.
// This plugin does not make HTTP/model calls or register tools.
export default {
  id: "sumire-quota-pool",
  async setup(ctx) {
    const retry = await ctx.session.hook("retry", (event) => {
      if (event.error.status === 429 || event.error.type === "provider.free-limit") {
        event.decision = { retry: false };
      }
    });
    return () => retry.dispose();
  },
};
