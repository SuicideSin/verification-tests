Feature: Update sql apb related feature

 # @author zitang@redhat.com
  @admin
  Scenario Outline: Plan of serviceinstance can be updated
    Given I save the first service broker registry prefix to :prefix clipboard
    #provision postgresql
    And I have a project
    When I run the :new_app client command with:
      | file  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/serviceinstance-template.yaml |
      | param | INSTANCE_NAME=<db_name>                                                                                      |
      | param | CLASS_EXTERNAL_NAME=<db_name>                                                                                |
      | param | PLAN_EXTERNAL_NAME=<db_plan_1>                                                                               |
      | param | SECRET_NAME=<secret_name>                                                                                    |
      | param | INSTANCE_NAMESPACE=<%= project.name %>                                                                       |
    Then the step should succeed
    And evaluation of `service_instance("<db_name>").uid` is stored in the :db_uid clipboard
    When I run the :new_app client command with:
      | file  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/serviceinstance-parameters-template.yaml                 |
      | param | SECRET_NAME=<secret_name>                                                                                                               |
      | param | INSTANCE_NAME=<db_name>                                                                                                                 |
      | param | PARAMETERS={"postgresql_database":"admin","postgresql_user":"admin","postgresql_version":"<db_version>","postgresql_password":"test"}   |
      | param | UID=<%= cb.db_uid %>                                                                                                                    |
      | n     | <%= project.name %>                                                                                                                     |
    Then the step should succeed
    Given I wait for the "<db_name>" service_instance to become ready up to 360 seconds
    And dc with name matching /postgresql/ are stored in the :dc_1 clipboard
    And a pod becomes ready with labels:
      | deploymentconfig=<%= cb.dc_1.first.name %> |

    # update instance 
     When I run the :patch client command with:
      | resource  | serviceinstance/<db_name>      |
      | p         |{                                                     |
      |           | "spec": {                                            |
      |           |    "clusterServicePlanExternalName": "<db_plan_2>"   | 
      |           |  }                                                   |
      |           |}                                                     |
    Then the step should succeed
    #checking the old dc is deleted, new dc is created   
    Given I wait for the resource "dc" named "<%= cb.dc_1.first.name %>" to disappear within 240 seconds
    Given I wait for the "<db_name>" service_instance to become ready up to 240 seconds
    When I run the :describe client command with:
      | resource  | serviceinstance/<db_name>      |
    Then the step should succeed
    And the output should match:
      | Reason:\\s+InstanceUpdatedSuccessfully |
    And the output should not contain:
      | UpdateInstanceCallFailed |
    And dc with name matching /postgresql/ are stored in the :dc_2 clipboard
    And a pod becomes ready with labels:
      | deploymentconfig=<%= cb.dc_2.first.name %> |
    
     Examples:
      |db_name                         |db_plan_1 |db_plan_2 |secret_name                                |db_version |
      |<%= cb.prefix %>-postgresql-apb |prod      |dev       |<%= cb.prefix %>-postgresql-apb-parameters |9.5        | # @case_id OCP-16151
      |<%= cb.prefix %>-postgresql-apb |dev       |prod      |<%= cb.prefix %>-postgresql-apb-parameters |9.5        | # @case_id OCP-18249
      |<%= cb.prefix %>-postgresql-apb |dev       |prod      |<%= cb.prefix %>-postgresql-apb-parameters |9.5        | # @case_id OCP-18308

