module Api
  # Api::CodeController is responsible for the interactive between browser/cli
  # and Docker Engine
  class CodeController < ActionController::API
    include ActionController::Live

    rescue_from Runner::NotFound do
      render text: 'Source code not found!', status: :unprocessable_entity
    end

    def register
      @runner = Runner.new(
        params.slice(:lang, :source, :version).merge(timeout: 15)
      )

      render plain: @runner.save
    end

    def run
      response.headers['Content-Type'] = 'text/event-stream'

      @runner = Runner.find(params[:uuid])
      @runner.run!(event_writer)
    rescue ClientDisconnected
      Rails.logger.info 'Streaming has been closed!'
    ensure
      cleanup
    end

    def stdin
      uuid = params[:uuid]
      stdin = params[:input]

      RedisPool.with_conn do |conn|
        conn.publish("#{uuid}#stdin", stdin)
      end

      render plain: ''
    end

    def save
      @runner = Runner.new(params.slice(:lang, :source, :version))

      (params[:code_id] || SecureRandom.urlsafe_base64).tap do |code_id|
        RedisPool.with_conn do |conn|
          conn.set("#{code_id}#snippet", @runner.to_json)
        end
        render plain: code_id
      end
    end

    def fetch
      raw_code_data = RedisPool.with_conn do |conn|
        conn.get("#{params[:codeID]}#snippet")
      end

      render json: raw_code_data
    end

    private

    def using_sse?
      params[:evt].present?
    end

    def event_writer
      @event_writer ||=
        if using_sse?
          SSE.new(response.stream, retry: 300, event: 'message')
        else
          response.stream
        end
    end

    def write_event(chunk)
      if using_sse?
        event_writer.write("#{chunk}\n\n")
      else
        event_writer.write("#{chunk}\n")
      end
    end

    def cleanup
      @runner.cleanup if defined?(@runner)
      event_writer.close
    end
  end
end
