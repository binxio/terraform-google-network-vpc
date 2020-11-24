package test

import (
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Give this network an environment to operate as a part of, for the purposes of resource tagging
// Give it a random string so we're sure it's created this test run
var expectedEnvironment string
var testPreq *testing.T
var terraformOptions *terraform.Options
var tmpSaReaderEmail string
var tmpSaOwnerEmail string
var blacklistRegions []string

func TestMain(m *testing.M) {
	expectedEnvironment = fmt.Sprintf("terratest %s", strings.ToLower(random.UniqueId()))
	blacklistRegions = []string{"asia-east2"}

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func(){
		<-c
		TestCleanup(testPreq)
		os.Exit(1)
	}()

	result := m.Run()

	Clean()

	os.Exit(result)
}

// -------------------------------------------------------------------------------------------------------- //
// Utility functions
// -------------------------------------------------------------------------------------------------------- //
func setTerraformOptions(dir string, region string, projectId string) {
	terraformOptions = &terraform.Options {
		TerraformDir: dir,
		// Pass the expectedEnvironment for tagging
		Vars: map[string]interface{}{
			"environment": expectedEnvironment,
			"location": region,
			"sa_reader_email": tmpSaReaderEmail,
			"sa_owner_email": tmpSaOwnerEmail,
		},
		EnvVars: map[string]string{
			"GOOGLE_CLOUD_PROJECT": projectId,
		},
	}
}

// A build step that removes temporary build and test files
func Clean() error {
	fmt.Println("Cleaning...")

	return filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && info.Name() == "vendor" {
			return filepath.SkipDir
		}
		if info.IsDir() && info.Name() == ".terraform" {
			os.RemoveAll(path)
			fmt.Printf("Removed \"%v\"\n", path)
			return filepath.SkipDir
		}
		if !info.IsDir() && (info.Name() == "terraform.tfstate" ||
		info.Name() == "terraform.tfplan" ||
		info.Name() == "terraform.tfstate.backup") {
			os.Remove(path)
			fmt.Printf("Removed \"%v\"\n", path)
		}
		return nil
	})
}

func Test_Prereq(t *testing.T) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions(".", region, projectId)
	testPreq = t

	terraform.InitAndApply(t, terraformOptions)

	tmpSaReaderEmail = terraform.OutputRequired(t, terraformOptions, "sa_reader_email")
	tmpSaOwnerEmail = terraform.OutputRequired(t, terraformOptions, "sa_owner_email")
}

// -------------------------------------------------------------------------------------------------------- //
// Unit Tests
// -------------------------------------------------------------------------------------------------------- //
func TestUT_Assertions(t *testing.T) {
	// Pick a random GCP region to test in. This helps ensure your code works in all regions.
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)

	expectedAssertUnknownVar := "Unknown subnet variable assigned"
	//expectedAssertDestination := "Destination rules should have both or neither of account_id and access_control_translation set."
	expectedAssertNameTooLong := "'s generated name is too long:"
	expectedAssertNameInvalidChars := "does not match regex"
	//expectedAssertKMSKeyMissing := "KMS Encryption key id is required."
	//expectedAssertBucketPolicies := "has both [bucket_access_policy_override] and [bucket_access_policy] defined, but only one can be applied"
	expectedAssertVPNTunnel := "like a VPN tunnel"
	expectedAssertHopCount := "supply ONE nexthop"
	expectedAssertPurposeWithoutRole := "subnet [no-role] has purpose [INTERNAL_HTTPS_LOAD_BALANCING] defined without"
	expectedAssertRoleWithInvalidPurpose := "subnet [role-with-wrong-purpose] has role [ACTIVE] defined while the 'purpose'"
	expectedAssertInvalidPurpose := "subnet [invalid-purpose]'s purpose [trigger-invalid] does not match"
	expectedAssertInvalidRole := "subnet [invalid-role]'s role [trigger-invalid] does not match"
	expectedAssertSubnetTooSmallForPurpose := "minimum is /26 for subnets with purpose INTERNAL_HTTPS"
	expectedAssertSubnetTooSmall := "is too small or invalid, minimum is /29"

	setTerraformOptions("assertions", region, projectId)

	out, err := terraform.InitAndPlanE(t, terraformOptions)

	require.Error(t, err)
	assert.Contains(t, out, expectedAssertUnknownVar)
	assert.Contains(t, out, expectedAssertNameTooLong)
	assert.Contains(t, out, expectedAssertNameInvalidChars)
	assert.Contains(t, out, expectedAssertVPNTunnel)
	assert.Contains(t, out, expectedAssertHopCount)
	assert.Contains(t, out, expectedAssertPurposeWithoutRole)
	assert.Contains(t, out, expectedAssertRoleWithInvalidPurpose)
	assert.Contains(t, out, expectedAssertInvalidPurpose)
	assert.Contains(t, out, expectedAssertInvalidRole)
	assert.Contains(t, out, expectedAssertSubnetTooSmallForPurpose)
	assert.Contains(t, out, expectedAssertSubnetTooSmall)
}

func TestUT_Defaults(t *testing.T) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions("defaults", region, projectId)
	terraform.InitAndPlan(t, terraformOptions)
}

func TestUT_Overrides(t *testing.T) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions("overrides", region, projectId)
	terraform.InitAndPlan(t, terraformOptions)
}

// -------------------------------------------------------------------------------------------------------- //
// Integration Tests
// -------------------------------------------------------------------------------------------------------- //

func TestIT_Defaults(t *testing.T) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions("defaults", region, projectId)

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	outputs := terraform.OutputAll(t, terraformOptions)

	// Ugly typecasting because Go....
	subnetMap := outputs["map"].(map[string]interface{})
	k8nodesSubnet := subnetMap["k8nodes"].(map[string]interface{})
	subnetId := k8nodesSubnet["id"].(string)

	// Make sure our subnet is created
	fmt.Printf("Checking subnet %s...\n", subnetId)
	// TODO: actual check
}

func TestIT_Overrides(t *testing.T) {
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions("overrides", region, projectId)

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	outputs := terraform.OutputAll(t, terraformOptions)

	// Ugly typecasting because Go....
	subnetMap := outputs["map"].(map[string]interface{})
	k8nodesSubnet := subnetMap["k8nodes"].(map[string]interface{})
	subnetId := k8nodesSubnet["id"].(string)

	// Make sure our subnet is created
	fmt.Printf("Checking subnet %s...\n", subnetId)
	// TODO: actual check
}

func TestCleanup(t *testing.T) {
	fmt.Println("Cleaning possible lingering resources..")
	terraform.Destroy(t, terraformOptions)

	// Also clean up prereq. resources
	fmt.Println("Cleaning our prereq resources...")
	projectId := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := gcp.GetRandomRegion(t, projectId, nil, blacklistRegions)
	setTerraformOptions(".", region, projectId)
	terraform.Destroy(t, terraformOptions)
}
