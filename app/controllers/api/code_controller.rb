class Api::CodeController < ActionController::API
  include ActionController::Live

  def register
    @runner = Runner.new(params.slice(:lang, :source, :version).merge(timeout: 15))

    render plain: @runner.save
  end

  def run
    response.headers['Content-Type'] = 'text/event-stream'

    Runner.find(params[:uuid]).tap do |runner|
      runner.create_container
      runner.start_container
      runner.attach_container do |chunk|
        event_writer.write chunk
      end
    end
  rescue Runner::NotFound
    render text: "Source code not found!", status: :unprocessable_entity
  ensure
    event_writer.close
  end

  def stdin
    uuid = params[:uuid]
    stdin = params[:input]

    Redis.new.publish("#{uuid}#stdin", stdin)

    render plain: ""
  end

  def save
    @runner = Runner.new(params.slice(:lang, :source, :version))

    (params[:code_id] || SecureRandom.urlsafe_base64).tap do |code_id|
      Redis.new.set("#{code_id}#snippet", @runner.to_json)
      render plain: code_id
    end
  end

  def fetch
    render json: Redis.new.get("#{params[:codeID]}#snippet")
  end

  private

  def using_sse?
    params[:evt].present?
  end

  def event_writer
    @event_writer ||= if using_sse?
      SSE.new(response.stream, retry: 300, event: "message")
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
end
