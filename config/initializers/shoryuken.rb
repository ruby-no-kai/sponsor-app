module Shoryuken
  module Middleware
    module Server
      class SentryReporter
        def call(worker_instance, queue, sqs_msg, body, &block)
          return block.call unless ::Sentry.initialized?

          ::Sentry.with_scope do |scope|
            begin
              contexts = generate_contexts(worker_instance, queue, sqs_msg, body)
              scope.set_contexts(**contexts)
              scope.set_tags("shoryuken.queue" => queue)
              name = contexts.dig(:'Active-Job', :job_class) || contexts.dig(:Shoryuken, :job_class)
              scope.set_transaction_name(name, source: :task)
              transaction = ::Sentry.start_transaction(name: scope.transaction_name, source: scope.transaction_source, op: "queue.shoryuken")
              scope.set_span(transaction) if transaction

              yield
            rescue Exception => exception
              ::Sentry.capture_exception(exception, hint: { background: false })
              finish_transaction(transaction, 500)
              raise
            end
          end
        end

        def generate_contexts(worker_instance, queue, sqs_msg, body)
          job_class = sqs_msg.message_attributes.dig('shoryuken_class', :string_value) || worker_instance&.class&.name

          context = {
            Shoryuken: {
              queue: queue,
              job_class: job_class.to_s,
            },
          }

          if job_class == 'ActiveJob::QueueAdapters::ShoryukenAdapter::JobWrapper'
            context[:"Active-Job"] = {
              job_class: body["job_class"],
              job_id: body["job_id"],
              arguments: body["arguments"],
              executions: body["executions"],
              exception_executions: body["exception_executions"],
              locale: body["locale"],
              enqueued_at: body["enqueued_at"],
              queue: queue,
            }
          else
            context[:Shoryuken][:body] = body
          end

          if sqs_msg.is_a?(Array) # not batch worker
            context[:Shoryuken][:batched] = true
          else
            context[:Shoryuken][:message_id] = sqs_msg.message_id
          end

          context
        end

        def finish_transaction(transaction, status)
          return unless transaction

          transaction.set_http_status(status)
          transaction.finish
        end
      end
    end
  end
end

Shoryuken.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Shoryuken::Middleware::Server::SentryReporter
  end

  config.sqs_client_receive_message_opts = {
    wait_time_seconds: 10,
    max_number_of_messages: 1,
  }
end
