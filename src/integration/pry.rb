require "util/nb-keyboard"

Fiber.new do
  EM.open_keyboard(NbKeyboard) do |kb|
    binding.pry
  end
end.resume
