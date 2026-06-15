const express = require("express");
const ctrl = require("../controllers/orgAdminExtendedController");
const billingCtrl = require("../controllers/billingController");
const staffCtrl = require("../controllers/staffRegistrationController");
const regReqCtrl = require("../controllers/registrationRequestAdminController");
const scheduleCtrl = require("../controllers/scheduleChangeRequestController");
const doctorLeaveCtrl = require("../controllers/doctorLeaveRequestController");
const adminCtrl = require("../controllers/adminController");
const adverseCtrl = require("../controllers/adverseReportController");

/** Public staff signup: POST /api/auth/register/staff → staffRegistrationController + models/Staff */

/**
 * Extended org-admin API (clinic admin, not platform super admin).
 * @param {{ requireOrgAdmin: (req: any, res: any) => Promise<any> }} deps
 */
function createOrgAdminExtendedRouter(deps) {
  const router = express.Router();
  const { requireOrgAdmin } = deps;

  function wrap(handler) {
    if (typeof handler !== "function") {
      throw new TypeError(
        `orgAdminExtendedRoutes: route handler must be a function, got ${typeof handler}`
      );
    }
    return async (req, res) => {
      try {
        const scoped = await requireOrgAdmin(req, res);
        if (!scoped) return;
        await handler(req, res, scoped);
      } catch (e) {
        console.error("[org-admin-ext]", e);
        res.status(500).json({ message: e.message || "Server error" });
      }
    };
  }

  router.get("/dashboard/stats", wrap(ctrl.getDashboardStats));
  router.get("/doctor-analytics", wrap(adminCtrl.getDoctorAnalytics));
  router.get("/adverse-analytics", wrap(adverseCtrl.getAdverseAnalytics));

  router.get("/departments", wrap(ctrl.listDepartments));
  router.post("/departments", wrap(ctrl.createDepartment));
  router.patch("/departments/:id", wrap(ctrl.updateDepartment));
  router.delete("/departments/:id", wrap(ctrl.deleteDepartment));
  router.post("/departments/:departmentId/clinics", wrap(ctrl.addDepartmentClinic));

  router.get("/doctors", wrap(ctrl.listDoctors));
  router.get("/pending-staff", wrap(staffCtrl.listPendingStaff));
  router.put("/approve-staff/:staffId", wrap(staffCtrl.approveStaff));

  router.get("/pending-registrations", wrap(regReqCtrl.listPending));
  router.get("/pending-requests", wrap(regReqCtrl.listPending));
  router.get("/requests", wrap(regReqCtrl.listPending));
  router.post("/pending-registrations/:requestId/approve", wrap(regReqCtrl.approve));
  router.post("/pending-registrations/:requestId/reject", wrap(regReqCtrl.reject));
  router.post("/requests/:requestId/approve", wrap(regReqCtrl.approve));
  router.post("/requests/:requestId/reject", wrap(regReqCtrl.reject));

  router.get("/schedule-change-requests", wrap(scheduleCtrl.listPendingForAdmin));
  router.post("/schedule-change-requests/:requestId/approve", wrap(scheduleCtrl.approveScheduleRequest));
  router.post("/schedule-change-requests/:requestId/reject", wrap(scheduleCtrl.rejectScheduleRequest));

  router.get("/staff", wrap(ctrl.listStaff));
  router.put("/staff/:userId/profile", wrap(ctrl.upsertStaffProfile));

  router.get("/patients", wrap(ctrl.getClinicPatients));
  router.get("/appointments", wrap(ctrl.getClinicAppointments));

  router.get("/staff-leave-requests", wrap(ctrl.listStaffLeave));
  router.patch("/staff-leave-requests/:id", wrap(ctrl.decideStaffLeave));

  router.get("/doctor-leave-requests", wrap(doctorLeaveCtrl.listDoctorLeaveForAdmin));
  router.patch("/doctor-leave-requests/:id", wrap(doctorLeaveCtrl.decideDoctorLeave));

  router.get("/medical-records", wrap(ctrl.listMedicalRecords));

  router.get("/billing/metrics", wrap(ctrl.getBillingMetrics));
  router.get("/billing/invoices", wrap(ctrl.listInvoices));
  router.get("/billing/ledger", wrap(billingCtrl.getLedger));
  router.post("/billing/invoices", wrap(ctrl.createInvoice));
  router.get("/billing/payroll/preview", wrap(billingCtrl.previewPayroll));
  router.post("/billing/payroll/generate", wrap(billingCtrl.generatePayroll));
  router.get("/billing/payroll/slips", wrap(billingCtrl.listPayrollSlips));

  router.get("/permissions", wrap(ctrl.getPermissions));
  router.put("/permissions", wrap(ctrl.updatePermissions));

  router.get("/inventory", wrap(ctrl.getInventory));
  router.put("/inventory", wrap(ctrl.updateInventory));

  router.get("/audit-logs", wrap(ctrl.listAuditLogs));

  router.post("/broadcast", wrap(ctrl.sendBroadcast));

  router.get("/system-config", wrap(ctrl.getSystemConfig));
  router.patch("/system-config", wrap(ctrl.updateSystemConfig));

  return router;
}

module.exports = createOrgAdminExtendedRouter;
