module ApplicationHelper
  # 10.0 → "10", 5.5 → "5.5", for number fields.
  def plain_number(value)
    float = value.to_f
    float == float.to_i ? float.to_i.to_s : float.to_s
  end
end
