module AuditSuppression
  def without_audit_log
    previously_enabled = PaperTrail.request.enabled?
    PaperTrail.request.enabled = false
    yield
  ensure
    PaperTrail.request.enabled = previously_enabled
  end
end
