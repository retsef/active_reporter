Dir.glob(File.join(__dir__, "report", "*.rb")).each { |file| require file }

module ActiveReporter
  class Report
    include ActiveReporter::Report::Definition
    include ActiveReporter::Report::Validation
    include ActiveReporter::Report::Metrics
    include ActiveReporter::Report::Aggregation    

    attr_reader :params, :parent_report, :parent_groupers, :supplements

    def initialize(params = {})
      @params = params

      # prepare the params for processing
      clean_params

      # When using a Calculator you may need the parent report data. Pass in a ActiveReporter::Report object when
      # instantiating a new ActiveReporter::Report instance as :parent_report. This will allow you to calculate a data
      # based on the #total_report of this passed :parent_report. For example, if the parent report includes a sum
      # aggregated "views" column, the child report can use Report::Calculator::Ratio to caluclate the ratio of "views"
      # on a given row versus the total "views" from the parent report.
      @parent_report = @params.delete(:parent_report)
      @parent_groupers = @params.delete(:parent_groupers) || ( grouper_names & Array(parent_report&.grouper_names) )

      # Supplements -> supplemental reports and data
      #
      # we need 2 items:
      # 1- the #supplements, a hash of reports and data, we can refrence by name
      # => this is passed into the report initializer, the key is the name the value is the enrire report object
      # 2- a configuration class, this will allow you to specify a special aggregator in the report class that
      # => take a block. The block defines { |key, row| return_value }, the block has access to the data in
      # #supplements available to use when calculating return the value.
      @supplements = @params.delete(:supplements)

      # You may pass in pre-compiled :row_data if you don't want ActiveReporter to compile this data for you. All
      # :calculators and :trackers will still be processed when :raw_data is passed in.
      @raw_data = @params.delete(:raw_data)

      # You may pass in pre-aggregated :total_report object as an instance of ActiveReporter::Report if you don't want
      # ActiveReporter to total this data for you no additional processing is completed on #total_report when a
      # :total_report value is passed.
      @total_report = @params.delete(:total_report)

      # Instead or in addition to passing a :total_report you may pass :total_data, which is used when report data is
      # built. In the case that both :total_report and :total_data are passed, the :total_report object will be used
      # for all :calculators. If only :total_data is passed, the :total_report object will not be populated and no
      # :calculators will be processed. Data in :total_data is never altered or appended.
      @total_data = @params.delete(:total_data) || @total_report&.data

      validate_params!

      # After params are parsed and validated you can call #data (or any derivitive of: #raw_data, #flat_data,
      # #hashed_data, #nested_data, etc.) on the ActiveReporter::Report object to #aggregate the data. This will
      # aggregate all the raw data by the configured dimensions, process any calculators, and then process any
      # trackers.
      
      # Caclulators calculate values using the current row data and the #parent_report.
      
      # Trackers calculate values using the current row data and prior row data.


      # If pre-compiled raw data was passed in, process all :calculators and :trackers now.
      aggregate if  @raw_data.present? && ( @params.include?(:calculators) || @params.include?(:trackers) )
      total if @total_data.present?
    end

    private

    def clean_params
      @params = @params.deep_symbolize_keys.deep_dup.compact
      strip_blank_params unless @params[:strip_blanks] == false
      compact_params
    end

    def strip_blank_params(check_params = @params)
      check_params.delete_if do |_, value|
        case value
        when Hash then strip_blank_params(value)
        when Array then value.reject! { |v| v.try(:blank?) }
        else value
        end.try(:blank?) unless value.is_a?(ActiveRecord::Relation)
      end
    end

    def compact_params
      # exclude raw report data in compact
      include_raw_data = @params.include?(:raw_data)
      raw_data = @params.delete(:raw_data) if include_raw_data
      include_total_data = @params.include?(:total_data)
      total_data = @params.delete(:total_data) if include_total_data

      DeeplyEnumerable::Hash.deep_compact(@params)

      # add raw report data back into params
      @params[:raw_data] = raw_data if include_raw_data
      @params[:total_data] = total_data if include_total_data

      @params
    end
  end
end
