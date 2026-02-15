module Pistonqueue
  module UnitExecution
    # method description : determine the number of fibers based on 'task_type'.
    # parameters :
    # - config : env value settings from client.
    # - task_type : the type of task that will be performed by the consumer.
    def fetch_fiber_limit(config:, task_type:)
      execution_profile = fiber_profile(config)

      begin
        execution_profile.fetch(task_type)
      rescue KeyError
        raise ArgumentError, "Unknown task_type: :#{task_type}. Available types are: #{execution_profile.keys}."
      end
    end

    private
      # method description : mapping the number of fibers based on the type of task.
      # parameters :
      # - config : env value settings from client.
      def fiber_profile(config)
        { 
          :io_bound_light => config.io_light_fiber.to_i, # suitable for the task : cache / logging.
          :io_bound_medium => config.io_medium_fiber.to_i, # suitable for the task : api call / query database.
          :io_bound_heavy => config.io_heavy_fiber.to_i, # suitable for the task : upload file / web scraping.
          :cpu_bound => config.cpu_fiber.to_i # suitable for the task : encryption / compression / image processing.
        }
      end
  end
end