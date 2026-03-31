import React, { useState } from "react";
import type { ExpenseReport } from "./types";
import { createReview } from "./api";

type AdminReviewFormProps = {
  report: ExpenseReport;
  reviewsUrl: string;
  onUpdate: (r: ExpenseReport) => void;
  onError: (e: string) => void;
};

export function AdminReviewForm({ report, reviewsUrl, onUpdate, onError }: AdminReviewFormProps) {
  const [comment, setComment] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (report.status === "draft") return null;

  const handleReview = async (actionType: "approve" | "reject") => {
    if (actionType === "reject" && !comment.trim()) {
      onError("A comment is required when rejecting");
      return;
    }

    const confirmMsg =
      actionType === "approve" ? "Approve this expense report?" : "Reject this expense report?";
    if (!confirm(confirmMsg)) return;

    setSubmitting(true);
    try {
      const result = await createReview(reviewsUrl, {
        action_type: actionType,
        comment: comment.trim() || null,
      });
      onUpdate(result);
      setComment("");
    } catch (e) {
      onError(e instanceof Error ? e.message : "Review failed");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="card mt-3">
      <div className="card-header">
        <strong>Review</strong>
      </div>
      <div className="card-body">
        <div className="form-group">
          <label className="small font-weight-bold">Comment (required for rejection)</label>
          <textarea
            className="form-control"
            rows={3}
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            disabled={submitting}
            placeholder="Feedback for the sponsor..."
          />
        </div>
        <div className="d-flex">
          <button
            className="btn btn-success mr-2"
            onClick={() => handleReview("approve")}
            disabled={submitting}
          >
            {submitting ? "..." : "Approve"}
          </button>
          <button
            className="btn btn-danger"
            onClick={() => handleReview("reject")}
            disabled={submitting}
          >
            {submitting ? "..." : "Reject"}
          </button>
        </div>
      </div>
    </div>
  );
}
