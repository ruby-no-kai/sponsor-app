FactoryBot.define do
  factory :tito_ticket_retraction do
    sponsorship
    conference { sponsorship&.conference }
    sequence(:tito_registration_id) { |n| "reg_#{n}" }
    reason { "Sponsor requested cancellation" }
    completed { false }

    trait :with_tito_registration do
      tito_registration do
        {
          'reference' => 'ABC123',
          'slug' => 'john-doe-abc123',
          'free' => true,
          'paid' => false,
          'refunded' => false,
          'partially_refunded' => false,
          'cancelled' => false,
          'tickets' => [
            {
              'release_id' => 'rel_1',
              'discount_code_used' => 'SPONSOR2025'
            }
          ]
        }
      end
    end

    trait :paid do
      tito_registration do
        {
          'reference' => 'ABC123',
          'slug' => 'john-doe-abc123',
          'free' => false,
          'paid' => true,
          'refunded' => false,
          'partially_refunded' => false,
          'cancelled' => false,
          'tickets' => [
            {
              'release_id' => 'rel_1',
              'discount_code_used' => 'SPONSOR2025'
            }
          ]
        }
      end
    end

    trait :cancelled do
      tito_registration do
        {
          'reference' => 'ABC123',
          'slug' => 'john-doe-abc123',
          'free' => true,
          'paid' => false,
          'refunded' => false,
          'partially_refunded' => false,
          'cancelled' => true,
          'tickets' => [
            {
              'release_id' => 'rel_1',
              'discount_code_used' => 'SPONSOR2025'
            }
          ]
        }
      end
    end

    trait :multiple_releases do
      tito_registration do
        {
          'reference' => 'ABC123',
          'slug' => 'john-doe-abc123',
          'free' => true,
          'paid' => false,
          'refunded' => false,
          'partially_refunded' => false,
          'cancelled' => false,
          'tickets' => [
            {
              'release_id' => 'rel_1',
              'discount_code_used' => 'SPONSOR2025'
            },
            {
              'release_id' => 'rel_2',
              'discount_code_used' => 'SPONSOR2025'
            }
          ]
        }
      end
    end

    trait :invalid_discount_code do
      tito_registration do
        {
          'reference' => 'ABC123',
          'slug' => 'john-doe-abc123',
          'free' => true,
          'paid' => false,
          'refunded' => false,
          'partially_refunded' => false,
          'cancelled' => false,
          'tickets' => [
            {
              'release_id' => 'rel_1',
              'discount_code_used' => 'INVALID_CODE'
            }
          ]
        }
      end
    end
  end
end
