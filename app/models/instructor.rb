class Instructor < User
  has_many :questionnaires, dependent: :nullify

  QUESTIONNAIRE = [['My questionnaires', 'list_mine'],
                   ['All public questionnaires', 'list_all']].freeze

  SIGNUPSHEET = [['My signups', 'list_mine'],
                 ['All public signups', 'list_all']].freeze

  ASSIGNMENT = [['My assignments', 'list_mine'],
                ['All public assignments', 'list_all']].freeze

  # Lists all objects of a certain type that are either owned by the user or are public.
  def list_all(object_type, user_id)
    object_type.where(instructor_id: user_id).or(object_type.where(private: false))
  end

  # Lists all objects of a certain type that are owned by the user.
  def list_mine(object_type, user_id)
    object_type.where(instructor_id: user_id)
  end

  # Gets an object of a certain type that is either owned by the user or is public.
  def get(object_type, id, user_id)
    object_type.find_by(id: id, instructor_id: user_id).or(object_type.find_by(id: id, private: false))
  end

  # Returns the IDs of the TAs for the courses that this instructor teaches.
  def my_tas
    courses = Course.includes(:ta_mappings).where(instructor_id: id)
    ta_ids = courses.flat_map { |course| course.ta_mappings.pluck(:ta_id) }
    ta_ids
  end

  # Returns a list of users who have the same or lower privilege level as the given user and are participants in the courses or assignments that the user instructs.
  def self.get_user_list(user)
    user_list = []
    courses = Course.includes(:participants).where(instructor_id: user.id)
    assignments = Assignment.includes(participants: :user).where(instructor_id: user.id)
    participants = courses.map(&:participants) + assignments.map(&:participants)
    participants.flatten.each do |participant|
      user_list << participant.user if user.role.has_all_privileges_of?(participant.user.role)
    end
    user_list
  end

end
