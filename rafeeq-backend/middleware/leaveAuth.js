/**
 * Attach authenticated user to req.user (with req.user.id) for leave endpoints.
 * @param {(req: any, res: any) => Promise<any>} requireAuth
 */
function createLeaveAuthMiddleware(requireAuth) {
  return async function leaveAuthMiddleware(req, res, next) {
    try {
      const user = await requireAuth(req, res);
      if (!user) return;
      req.user = {
        ...user,
        id: String(user._id),
      };
      next();
    } catch (err) {
      next(err);
    }
  };
}

module.exports = { createLeaveAuthMiddleware };
