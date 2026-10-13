import { createBrowserRouter } from "react-router";
import { Root, RootFallback } from "./routes/Root.tsx";
import { NotFound, RootError, RouteError } from "./routes/RouteError.tsx";
import { paths } from "./routes/paths.ts";

// Two trees: the staff area under /admin, and the sponsor area for every other path. Each path
// here also needs its pattern in paths.ts, or the dev server sends page loads of it to Rails.
export const router = createBrowserRouter([
  {
    Component: Root,
    ErrorBoundary: RootError,
    HydrateFallback: RootFallback,
    children: [
      {
        path: paths.admin,
        lazy: { Component: async () => (await import("./routes/admin/AdminLayout.tsx")).default },
        children: [
          {
            // Inside the layout, so the sidebar stays when a page fails.
            ErrorBoundary: RouteError,
            children: [
              // Conferences
              {
                index: true,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ConferenceList.tsx")).default,
                },
              },
              {
                path: paths.conferences,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ConferenceList.tsx")).default,
                },
              },
              {
                path: paths.conferenceNew,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ConferenceEditor.tsx")).default,
                },
              },
              {
                path: paths.conference,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ConferenceOverview.tsx")).default,
                },
              },
              {
                path: paths.conferenceEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ConferenceEditor.tsx")).default,
                },
              },
              {
                path: paths.attendeesKeeper,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/AttendeesKeeper.tsx")).default,
                },
              },
              {
                path: paths.sponsorshipTable,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/SponsorshipTable.tsx")).default,
                },
              },

              // Form descriptions
              {
                path: paths.formDescriptionNew,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/FormDescriptionEditor.tsx")).default,
                },
              },
              {
                path: paths.formDescription,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/FormDescriptionEditor.tsx")).default,
                },
              },
              {
                path: paths.formDescriptionEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/FormDescriptionEditor.tsx")).default,
                },
              },

              // Plans
              {
                path: paths.plans,
                lazy: {
                  Component: async () => (await import("./routes/admin/PlanList.tsx")).default,
                },
              },
              {
                path: paths.planNew,
                lazy: {
                  Component: async () => (await import("./routes/admin/PlanEditor.tsx")).default,
                },
              },
              {
                path: paths.planEdit,
                lazy: {
                  Component: async () => (await import("./routes/admin/PlanEditor.tsx")).default,
                },
              },

              // Sponsorships
              {
                path: paths.sponsorship,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/SponsorshipDetail.tsx")).default,
                },
              },
              {
                path: paths.sponsorshipEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/SponsorshipEditor.tsx")).default,
                },
              },
              {
                path: paths.sponsorshipEditingHistory,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/SponsorshipEditingHistory.tsx")).default,
                },
              },
              {
                path: paths.sponsorshipStaffNotes,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/SponsorshipStaffNotes.tsx")).default,
                },
              },

              // Organizations
              {
                path: paths.organizations,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/OrganizationList.tsx")).default,
                },
              },
              {
                path: paths.organizationNew,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/OrganizationEditor.tsx")).default,
                },
              },
              {
                path: paths.organization,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/OrganizationDetail.tsx")).default,
                },
              },
              {
                path: paths.organizationEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/OrganizationEditor.tsx")).default,
                },
              },

              // Booth assignments
              {
                path: paths.boothAssignment,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/BoothAssignmentEditor.tsx")).default,
                },
              },

              // Sponsor events
              {
                path: paths.sponsorEvents,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/SponsorEventList.tsx")).default,
                },
              },
              {
                path: paths.sponsorEvent,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/SponsorEventDetail.tsx")).default,
                },
              },
              {
                path: paths.sponsorEventEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/SponsorEventEditor.tsx")).default,
                },
              },
              {
                path: paths.sponsorEventEditingHistory,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/SponsorEventEditingHistory.tsx")).default,
                },
              },

              // Announcements
              {
                path: paths.announcements,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/AnnouncementList.tsx")).default,
                },
              },
              {
                path: paths.announcementNew,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/AnnouncementEditor.tsx")).default,
                },
              },
              {
                path: paths.announcement,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/AnnouncementDetail.tsx")).default,
                },
              },
              {
                path: paths.announcementEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/AnnouncementEditor.tsx")).default,
                },
              },

              // Broadcasts
              {
                path: paths.broadcasts,
                lazy: {
                  Component: async () => (await import("./routes/admin/BroadcastList.tsx")).default,
                },
              },
              {
                path: paths.broadcastNew,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/BroadcastEditor.tsx")).default,
                },
              },
              {
                path: paths.broadcast,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/BroadcastDetail.tsx")).default,
                },
              },
              {
                path: paths.broadcastEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/BroadcastEditor.tsx")).default,
                },
              },

              // Expense reports
              {
                path: paths.expenseReports,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ExpenseReportList.tsx")).default,
                },
              },
              {
                path: paths.expenseReport,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/expense_report/ExpenseReportEditor.tsx")).default,
                },
              },

              { path: "*", Component: NotFound },
            ],
          },
        ],
      },
      {
        lazy: {
          Component: async () => (await import("./routes/sponsor/SponsorLayout.tsx")).default,
        },
        children: [
          {
            // Inside the layout, which provides the texts these read.
            lazy: {
              ErrorBoundary: async () =>
                (await import("./routes/sponsor/SponsorRouteError.tsx")).SponsorRouteError,
            },
            children: [
              // Sponsor: Shell
              {
                path: paths.sponsorLanding,
                lazy: {
                  Component: async () => (await import("./routes/sponsor/Landing.tsx")).default,
                },
              },
              {
                path: paths.sponsorConferences,
                lazy: {
                  Component: async () =>
                    (await import("./routes/sponsor/ConferencePicker.tsx")).default,
                },
              },
              {
                path: paths.sponsorDashboard,
                lazy: {
                  Component: async () => (await import("./routes/sponsor/Dashboard.tsx")).default,
                },
              },

              // Sponsor: Applications
              {
                path: paths.sponsorApplicationNew,
                lazy: {
                  Component: async () =>
                    (await import("./routes/sponsor/NewApplication.tsx")).default,
                },
              },
              {
                path: paths.sponsorApplicationEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/sponsor/EditApplication.tsx")).default,
                },
              },

              // Sponsor: Exhibitions and events
              {
                path: paths.sponsorExhibitionNew,
                lazy: {
                  Component: async () =>
                    (await import("./routes/sponsor/ExhibitionEditor.tsx")).NewExhibition,
                },
              },
              {
                path: paths.sponsorExhibitionEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/sponsor/ExhibitionEditor.tsx")).EditExhibition,
                },
              },

              // Sponsor: Broadcasts and passes
              {
                path: paths.sponsorBroadcasts,
                lazy: {
                  Component: async () => (await import("./routes/sponsor/Broadcasts.tsx")).default,
                },
              },
              {
                path: paths.sponsorPassRedemptions,
                lazy: {
                  Component: async () =>
                    (await import("./routes/sponsor/PassRedemptions.tsx")).default,
                },
              },
              {
                path: paths.sponsorPassRetractionNew,
                lazy: {
                  Component: async () =>
                    (await import("./routes/sponsor/PassRetractionForm.tsx")).default,
                },
              },
              {
                path: paths.sponsorPassRetraction,
                lazy: {
                  Component: async () =>
                    (await import("./routes/sponsor/PassRetraction.tsx")).default,
                },
              },

              // Sponsor: Expense reports

              {
                path: "*",
                lazy: {
                  Component: async () =>
                    (await import("./routes/sponsor/SponsorRouteError.tsx")).SponsorNotFound,
                },
              },
            ],
          },
        ],
      },
    ],
  },
]);
