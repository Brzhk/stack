import com.cloudbees.jenkins.plugins.amazonecs.ECSCloud
import com.cloudbees.jenkins.plugins.amazonecs.ECSTaskTemplate
import hudson.plugins.git.GitSCM
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.csrf.DefaultCrumbIssuer
import jenkins.CLI
import jenkins.model.Jenkins
import jenkins.model.JenkinsLocationConfiguration
import jenkins.security.s2m.AdminWhitelistRule
import jenkins.slaves.JnlpSlaveAgentProtocol4

import java.util.logging.Logger

def logger = Logger.getLogger("")
final Jenkins instance = Jenkins.getInstance()

def adminUsername = System.getenv('JENKINS_ADMIN_USERNAME') ?: 'admin'
def adminPassword = System.getenv('JENKINS_ADMIN_PASSWORD') ?: 'admin'
def slaveAgentPort = System.getenv('JENKINS_SLAVE_AGENT_PORT') ?: 'admin'

if (!instance.useSecurity) {


    HudsonPrivateSecurityRealm hudsonRealm = new HudsonPrivateSecurityRealm(false)

    if (null == instance.getSecurityRealms(hudsonRealm.getDescriptor().getId())) {

        println "--> creating first user '${adminUsername}' with "
        hudsonRealm.createAccount(adminUsername, adminPassword)

        println "--> setting full control once logger authorization strategy"
        FullControlOnceLoggedInAuthorizationStrategy strategy = new FullControlOnceLoggedInAuthorizationStrategy()
        instance.setAuthorizationStrategy(strategy)

    }




    println "--> disabling CLI remote access"
    CLI.get().setEnabled(false)

    println "--> creating crumb issuer"
    DefaultCrumbIssuer defaultCrumbIssuer = new DefaultCrumbIssuer(true)
    instance.crumbIssuer = defaultCrumbIssuer

    println "--> enabling slave access control mechanism"
    instance.getInjector().getInstance(AdminWhitelistRule.class)
            .setMasterKillSwitch(false)

    instance.setSecurityRealm(hudsonRealm)

    def current_slaveport = instance.getSlaveAgentPort()

    if (current_slaveport != defined_slaveport) {
        println "--> setting slave port"
        instance.setSlaveAgentPort(defined_slaveport)
        logger.info("Slaveport set to " + defined_slaveport)

    }


    def jenkinsLocationConfiguration = JenkinsLocationConfiguration.get()

    jenkinsLocationConfiguration.setAdminAddress("Brzhk <berzehk@gmail.com>")
    jenkinsLocationConfiguration.setUrl("https://jenkins.brzhk.wtf/")
    jenkinsLocationConfiguration.save()


    GitSCM.DescriptorImpl gitDesc = Jenkins.instance.getExtensionList(GitSCM.DescriptorImpl.class).getAt(0)
    gitDesc.globalConfigEmail = "berzehk@gmail.com"
    gitDesc.globalConfigName = "Brzhk"
    gitDesc.createAccountBasedOnEmail = false
    gitDesc.save()

    println "--> configuring slave management"

    List<ECSTaskTemplate.LogDriverOption> logDriverOptions = Collections.singletonList(new ECSTaskTemplate.LogDriverOption("tag", taskTemplateName))
    List<ECSTaskTemplate.EnvironmentEntry> environments = Collections.EMPTY_LIST
    List<ECSTaskTemplate.ExtraHostEntry> extraHosts = Collections.EMPTY_LIST
    List<ECSTaskTemplate.MountPointEntry> mountPoints = Collections.EMPTY_LIST
    ECSTaskTemplate taskTemplate = new ECSTaskTemplate(taskTemplateName, taskLabel, taskImage, taskRemoteFSRoot, taskMemory, taskMemoryReservation, taskCpu, privileged, logDriverOptions, environments, extraHosts, mountPoints)
    taskTemplate.setLogDriver(tasklogDriver)

    def awsAccountId = 759204445141
    def clusterName = "forge"
    def jenkinsInternalUrl = "jenkins.stack.local"
    def cloudName = clusterName
    def cloudClusterArn = "arn:aws:ecs:eu-west-1:" + awsAccountId + ":cluster/" + clusterName
    def tunnel = jenkinsInternalUrl + ":50000"
    def jenkinsUrl = "http://" + jenkinsInternalUrl + "/"
    def emptyCreds = ""
    def regionName = "eu-west-1"
    def slaveTimeoutInSeconds = 900

    ECSCloud ecsCloud = new ECSCloud(cloudName, Collections.<com.cloudbees.jenkins.plugins.amazonecs.ECSTaskTemplate> singletonList(taskTemplate), emptyCreds, cloudClusterArn, regionName, jenkinsUrl, slaveTimeoutInSeconds)
    ecsCloud.tunnel = tunnel

    instance.clouds.add(ecsCloud)

} else
    println "Admin found"

instance.save()
