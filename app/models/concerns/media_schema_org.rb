module MediaSchemaOrg
  extend ActiveSupport::Concern

  def get_schema_data
    return if self.doc.nil?
    microdata = Mida::Document.new(self.doc)
    if !microdata.items.empty?
      self.data[:schema] ||= {}.with_indifferent_access
      microdata.items.each do |item|
        next if item.type.nil?
        type = schema_type(item.type)
        add_schema_to_data(self, schema_mapping(item.to_h.with_indifferent_access), type) if type
      end
    end
  end

  def schema_type(item_type)
    type = item_type.match(/^https?:\/\/schema\.org\/(.*)/)
    return type[1] if type
  end

  def schema_mapping(item)
    if item[:properties]
      item.merge!(item[:properties])
      item.delete(:properties)
    end
    schema = item.clone
    item.each do |key, value|
      schema = check_type_pattern(key, value, schema)
      if value.is_a?(Array) && value.size == 1
        schema[key] = value.first
      end
      if schema[key].is_a? Hash
        schema[key] = schema_mapping(schema[key])
      end
    end
    schema
  end

  def check_type_pattern(key, value, schema)
    return schema unless key.to_sym == :type
    schema['@type'] = schema_type(value) || value
    schema.delete(key)
    schema
  end

  def add_schema_to_data(media, data, type)
    data['@context'] ||= 'http://schema.org'
    media.data[:schema] ||= {}.with_indifferent_access
    media.data['schema'][type] ||= []
    media.data['schema'][type] << data.with_indifferent_access
  end

end
