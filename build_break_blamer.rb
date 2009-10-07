class BuildBreakBlamer
  attr_accessor :success_listeners
  attr_reader :author_commits

  def initialize(project)
    @project = project

    self.success_listeners = []
  end

  def build_initiated
    @author_commits = @project.source_control.new_revisions.inject({}) do |acc, revision|
      acc[revision.author] ||= []
      acc[revision.author] << revision
      acc
    end
  end

  def build_finished build
    blame_breakers(build) if build.failed?

    report_success(build) if !build.failed? && revision_changed?
  end

  private

  def revision_changed?; !author_commits.blank? end

  def blame_breakers build
    author_commits.each do |(author, revisions)|
      message = "Dude, the #{build.project.name} broke after pulling some of your commits. Here's the summary of your commits:\n\n"

      revisions.each { |revision| message += "#{revision.number}: #{revision.message}\n" }

      message << "\n\nPlease fix it. :)"

      email build, author, "Your commit broke #{build.project.name} build #{build.label}", message
    end
  end

  def report_success build
    email build, success_listeners, "A new working build has been successfully pushed", "Build #{build.label} has been pushed, tested and possibly deployed. Enjoy!"
  end

  def email build, email, subject, message
    from = Configuration.email_from

    BuildMailer.deliver_build_report build, Array(email), from, subject, message
  end
end

Project.plugin :build_break_blamer
