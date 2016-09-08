class ExportProcessor
  @queue = :normal

  attr_accessor :retry_batch, :order_id
  def initialize(options)
    self.retry_batch = options.fetch(:retry, false)
    self.order_id = options.fetch(:order_id, nil)
  end

  def batches
    @batches ||= fetch_batches
  end

  def fetch_batches
    if retry_batch
      Batch.by_status('submitted')
    elsif order_id.present?
      [Batch.batch_order(order_id)]
    else
      [Batch.batch_orders].compact
    end
  end

  def perform
    Rails.logger.info "start ExportProcessor::perform"

    batches = fetch_batches
    if batches.any?
      batches.each do |batch|
        file = create_batch_file(batch)

        Rails.logger.info "created batch file #{file.inspect}"

        send_file(file)

        Rails.logger.info "delivered batch file to the remote host"

        batch.update_attribute :status, Batch.DELIVERED
        batch.orders.each{|o| o.complete_export!}

        Rails.logger.info "updated batch and order statuses"
      end
    else
      Rails.logger.info "No orders to export"
    end

    Rails.logger.info "end ExportProcessor::perform"
  rescue => e
    Rails.logger.error "Unable to complete the export. batches=#{batches.inspect} error: #{e.class.name} : #{e.message}\n  #{e.backtrace.join("\n  ")}"
  end

  def self.perform(options = {})
    ExportProcessor.
      new((options || {}).with_indifferent_access).
      perform
  end

  private

  def create_batch_file(batch)
    writer = Lsi::BatchWriter.new(batch)
    file = StringIO.new
    writer.write file
    file.rewind
    file
  end

  def remote_file_name
    "PPO.M#{DateTime.now.utc.strftime('%m%d%H%M')}"
  end

  def send_file(file)
    REMOTE_FILE_PROVIDER.send_file(file, remote_file_name, 'incoming')
  end
end
