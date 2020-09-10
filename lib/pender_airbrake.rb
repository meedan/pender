class PenderAirbrake
  def self.notify(e, data = {})
    Airbrake.notify(e, data) if Airbrake.configured?
  end
end
