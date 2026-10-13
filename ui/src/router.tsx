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

              // Sponsor events

              // Announcements

              // Broadcasts

              // Expense reports

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
          // Sponsor: Translations

          // Sponsor: Applications

          // Sponsor: Exhibitions and events

          // Sponsor: Broadcasts and passes

          // Sponsor: Expense reports

          { path: "*", Component: NotFound },
        ],
      },
    ],
  },
]);
