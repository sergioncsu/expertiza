# The Ta class inherits from the User class and represents a teaching assistant (TA).
class Ta < User
  # A TA has many ta_mappings, which are destroyed if the TA is destroyed.
  has_many :ta_mappings, dependent: :destroy

  # Constants for questionnaires and assignments.
  QUESTIONNAIRE = [['My questionnaires', 'list_mine'],
                   ['All public questionnaires', 'list_all']].freeze

  ASSIGNMENT = [['My assignments', 'list_mine'],
                ['All public assignments', 'list_all']].freeze

  # Returns the courses that the TA assists with.              
  def courses_assisted_with
    TaMapping.where(ta_id: id).map { |c| Course.find(c.course_id) }
  end
  
  # Checks if the TA is an instructor or co-TA for a given questionnaire.
  def is_instructor_or_co_ta?(questionnaire)
    return false if questionnaire.nil?

    # Check if is TA for any of the courses of a given questionnaire's instructor
    instructor_id = questionnaire.instructor_id
    return true if Ta.get_my_instructors(id).include?(instructor_id)

    questionnaire_ta = Ta.find(instructor_id)
    courses_assisted_with.any? { |course| course.tas.include?(questionnaire_ta) }
  end
  
  # Lists all objects of a certain type that are either owned by the user or are public.
  def list_all(object_type, user_id)
    object_type.where(['instructor_id = ? OR private = 0', user_id])
  end

  def list_mine(object_type, user_id)
    #### if we are loading "My Assignments" for a user who is a TA we need to find all assignments
    #### which are assigned to a course for which the user is a TA (in addition to his own assignments
    #### which he created
    if object_type.to_s.eql? 'Assignment'
      #### once the course_id on the assignments table is being assigned properly we can use
      #### this find method, until then use the one below.
      # Assignment.find_by_sql(["select assignments.id, assignments.name, assignments.directory_path " +
      #  "from assignments inner join ta_mappings ON (assignments.course_id=ta_mappings.course_id and ta_id=?) " +
      #  "UNION select assignments.id, assignments.name, assignments.directory_path from assignments where instructor_id=?",user_id,user_id])

      #### this find method compares the directories of an assignment and a course to find out if the
      #### the assignment is in a subdirectory of a course that the user is a TA for.
      Assignment.find_by_sql(['SELECT assignments.id, assignments.name, assignments.directory_path ' \
      'FROM assignments, ta_mappings where assignments.course_id = ta_mappings.course_id and ta_mappings.ta_id=?', user_id])
    else
      object_type.where(['instructor_id = ?', user_id])
    end
  end

  # Gets an object of a certain type that is either owned by the user or is public.
  def get(object_type, id, user_id)
    object_type.where(['id = ? AND (instructor_id = ? OR private = 0)', id, user_id]).first
  end

  # This method is potentially problematic: it assumes one TA only help teach one course.
  # This method only returns the instructor_id for the 1st course that this user help teach.  -Yang Oct. 05 2015
  def self.get_my_instructor(user_id)
    course_id = TaMapping.get_course_id(user_id)
    Course.find(course_id).instructor_id
  end

  # This method should be used to replace the "get_my_instructor" method
  # Returns all instructor IDs for courses that this TA helps teach.
  def self.get_my_instructors(user_id)
    TaMapping.where(ta_id: user_id).joins(:course).pluck('courses.instructor_id')
  end

  # Returns all instructor IDs for courses that this TA helps teach.
  def self.get_mapped_instructor_ids(user_id)
    TaMapping.where(ta_id: user_id).joins(:course).pluck('courses.instructor_id')
  end

  # Returns all course IDs for courses that this TA helps teach.
  def self.get_mapped_courses(user_id)
    TaMapping.where(ta_id: user_id).pluck(:course_id)
  end
  
  # Returns the instructor ID for the first course that this TA helps teach.
  def get_instructor
    Ta.get_my_instructor(id)
  end

  # Sets the instructor and course ID for a new assignment.
  def set_instructor(new_assign)
    new_assign.instructor_id = Ta.get_my_instructor(id)
    new_assign.course_id = TaMapping.get_course_id(id)
  end

  def assign_courses_to_assignment
    @courses = TaMapping.get_courses(id)
  end

  # Returns true to indicate that the user is a teaching assistant.
  def teaching_assistant?
    true
  end
  
  # Returns a list of users who have the same or lower privilege level as the given user and are participants in the courses that the user is a TA for.
  def self.get_user_list(user)
    # Get the IDs of the courses that the user is a TA for.
    courses = Ta.get_mapped_courses(user.id)
    participants = []
    user_list = []

    # For each course, get the participants and add them to the participants array.
    courses.each do |course_id|
      course = Course.find(course_id)
      participants << course.get_participants
    end

    # For each participant, if they have the same or lower privilege level as the user, add them to the user list.
    participants.each do |p_s|
      next if p_s.empty?

      p_s.each do |p|
        user_list << p.user if user.role.has_all_privileges_of?(p.user.role)
      end
    end

    # Return the list of users.
    user_list
  end

  def self.get_user_list(user)
    courses = Ta.get_mapped_courses(user.id)
    participants = courses.flat_map { |course_id| Course.find(course_id).get_participants }
    participants.select { |p| user.role.has_all_privileges_of?(p.user.role) }.map(&:user)
  endgit 
end