# frozen_string_literal: true

class NilResponder
  # catches any call and returns nil.
  def method_missing(*_args, &) = nil

  # ensures that the object "responds" to any method.
  def respond_to_missing?(*_args) = true
end
