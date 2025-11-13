FactoryBot.define do
  factory :announcement do
    conference
    staff
    sequence(:issue) { |n| "issue-#{n}" }
    locale { 'en' }
    sequence(:title) { |n| "Announcement #{n}" }
    body { "This is an announcement body" }
    revision { 1 }

    trait :published do
      published_at { Time.current }
    end

    trait :exhibitors_only do
      exhibitors_only { true }
    end

    trait :pinned do
      stickiness { 10 }
    end
  end
end
