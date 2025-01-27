/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * The input to the SEPConfiguratorResource
 */
export interface SEPConfiguratorResourceProps {
  /**
   * Info for connecting to the Render Queue.
   */
  readonly connection: ConnectionOptions;

  /**
   * The Spot Fleet Request Configurations.
   * See https://docs.thinkboxsoftware.com/products/deadline/10.1/1_User%20Manual/manual/event-spot.html#example-spot-fleet-request-configurations
   */
  readonly spotFleetRequestConfigurations?: SpotFleetRequestConfiguration;

  /**
   * The Spot Event Plugin settings.
   * See https://docs.thinkboxsoftware.com/products/deadline/10.1/1_User%20Manual/manual/event-spot.html#event-plugin-configuration-options
   */
  readonly spotPluginConfigurations?: PluginSettings;

  /**
   * Deadline groups that are used by these fleets.
   */
  readonly deadlineGroups?: string[];

  /**
   * Deadline pools that are used by these fleets.
   */
  readonly deadlinePools?: string[];
}

/**
 * Values required for establishing a connection to a TLS-enabled Render Queue.
 */
export interface ConnectionOptions {
  /**
   * Fully qualified domain name of the Render Queue.
   */
  readonly hostname: string;

  /**
   * Port on the Render Queue to connect to.
   */
  readonly port: string;

  /**
   * Protocol used to connect to the Render Queue.
   * Allowed values: 'HTTP' and 'HTTPS'.
   */
  readonly protocol: string;

  /**
   * The ARN of the CA certificate stored in the SecretsManager.
   */
  readonly caCertificateArn?: string;
}

/**
 * Interface for communication between Lambda and ConfigureSpotEventPlugin construct.
 * The properties correspond to SpotEventPluginSettings from '../../../deadline/lib/configure-spot-event-plugin',
 * but the types and names may differ.
 */
export interface PluginSettings {
  /**
   * The Worker Extra Info column to be used to display AWS Instance Status
   */
  readonly AWSInstanceStatus: string;

  /**
   * Determines if EC2 Spot interrupted AWS Workers will be deleted from the Workers Panel on the next House Cleaning cycle.
   */
  readonly DeleteInterruptedSlaves: boolean;

  /**
   * Determines if Deadline Spot Event Plugin terminated AWS Workers will be deleted from the Workers Panel on the next House Cleaning cycle.
   */
  readonly DeleteTerminatedSlaves: boolean;

  /**
   * The number of minutes an AWS Worker will wait in a non-rendering state before it is shutdown.
   */
  readonly IdleShutdown: number;

  /**
   * Spot Event Plugin logging level.
   */
  readonly Logging: string;

  /**
   * Determines how the Spot Event Plugin should handle Pre Job Tasks.
   */
  readonly PreJobTaskMode: string;

  /**
   * The AWS region in which to start the spot fleet request.
   */
  readonly Region: string;

  /**
   * Determines whether the Deadline Resource Tracker should be used.
   */
  readonly ResourceTracker: boolean;

  /**
   * The Spot Event Plugin will request this maximum number of instances per House Cleaning cycle.
   */
  readonly StaggerInstances: number;

  /**
   * How the event plug-in should respond to events.
   */
  readonly State: string;

  /**
   * Determines if any active instances greater than the target capacity for each group will be terminated.
   */
  readonly StrictHardCap: boolean;
}

/**
 * The interface representing the Spot Fleet Request Configurations (see https://docs.thinkboxsoftware.com/products/deadline/10.1/1_User%20Manual/manual/event-spot.html#spot-fleet-request-configurations).
 * Used for communication between Lambda and ConfigureSpotEventPlugin construct.
 */
export interface SpotFleetRequestConfiguration {
  [groupName: string]: SpotFleetRequestProps;
}

/**
 * Represents a single Spot Fleet Request Configuration that will be mapped to a Deadline Group.
 */
export interface SpotFleetRequestProps {
  /**
   * Indicates how to allocate the target Spot Instance capacity
   * across the Spot Instance pools specified by the Spot Fleet request.
   */
  readonly AllocationStrategy: string;

  /**
   * An ARN of the Spot Fleet IAM role.
   */
  readonly IamFleetRole: string;

  /**
   * The launch specifications for the Spot Fleet request.
   *
   * @deprecated This property is ignored. Use `LaunchTemplateConfigs` instead.
   */
  readonly LaunchSpecifications?: any[];

  /**
   * The launch templates for the Spot Fleet request.
   */
  readonly LaunchTemplateConfigs?: LaunchTemplateConfig[];

  /**
   * Indicates whether Spot Fleet should replace unhealthy instances.
   */
  readonly ReplaceUnhealthyInstances: boolean;

  /**
   * In order to work with Deadline, the 'Target Capacity' of the Spot fleet Request is
   * the maximum number of Workers that Deadline will start.
   */
  readonly TargetCapacity: number;

  /**
   * Indicates whether running Spot Instances are terminated when the Spot Fleet request expires.
   */
  readonly TerminateInstancesWithExpiration: boolean;

  /**
   * The type of request. Indicates whether the Spot Fleet only requests the target capacity or also attempts to maintain it.
   */
  readonly Type: string;

  /**
   * The tags to apply to the Spot Fleet Request during creation.
   */
  readonly TagSpecifications: SpotFleetTagSpecification[];

  /**
   * The end date and time of the request, in UTC format.
   * After the end date and time, no new Spot Instance requests are placed or able to fulfill the request.
   *
   * @default - the Spot Fleet request remains until you cancel it.
   */
  readonly ValidUntil?: string;
}

/**
 * Interface for `FleetLaunchTemplateSpecification` used in the `RequestSpotFleet` API invoked by SEP.
 * @see https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_RequestSpotFleet.html
 * @see https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_FleetLaunchTemplateSpecification.html
 */
export interface LaunchTemplateSpecification {
  /**
   * The ID of the launch template. This is mutually exclusive with `LaunchTemplateName`.
   */
  readonly LaunchTemplateId?: string;
  /**
   * The name of the launch template. This is mutually exclusive with `LaunchTemplateId`.
   */
  readonly LaunchTemplateName?: string;
  /**
   * The version of the launch template to use.
   */
  readonly Version: string;
}

/**
 * Interface for `LaunchTemplateOverrides` used in the `RequestSpotFleet` API invoked by SEP.
 * @see https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_RequestSpotFleet.html
 * @see https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_LaunchTemplateOverrides.html
 */
export interface LaunchTemplateOverrides {
  /**
   * The Availability Zone in which to launch the instances.
   */
  readonly AvailabilityZone?: string,
  /**
   * The instance type.
   */
  readonly InstanceType?: string,
  /**
   * The maximum price per unit hour you are willing to pay for a Spot Instance.
   */
  readonly SpotPrice?: string,
  /**
   * The ID of the subnet in which to launch the instances.
   */
  readonly SubnetId?: string,
  /**
   * The number of units provided by the specified instance type.
   */
  readonly WeightedCapacity?: number,
}

/**
 * Interface for `LaunchTemplateConfig` used in the `RequestSpotFleet` API invoked by SEP.
 * @see https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_RequestSpotFleet.html
 * @see https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_LaunchTemplateConfig.html
 */
export interface LaunchTemplateConfig {
  /**
   * The launch template.
   */
  readonly LaunchTemplateSpecification: LaunchTemplateSpecification;
  /**
   * Any parameters that you specify override the same parameters in the launch template.
   */
  readonly Overrides: LaunchTemplateOverrides[];
}

/**
 * Describes a block device mapping.
 * The following interface represents a CfnLaunchConfiguration.BlockDeviceMappingProperty interface.
*/
export interface BlockDeviceMappingProperty {
  /**
   * The device name (for example, /dev/sdh or xvdh ).
   */
  readonly DeviceName: string;

  /**
   * Parameters used to automatically set up EBS volumes when the instance is launched.
   *
   * @default - Property not used.
   */
  readonly Ebs?: BlockDeviceProperty;

  /**
   * To omit the device from the block device mapping, specify an empty string.
   *
   * @default - Property not used.
   */
  readonly NoDevice?: string;

  /**
   * The virtual device name (ephemeral N).
   *
   * @default - Property not used.
   */
  readonly VirtualName?: string;
}

/**
 * Parameters used to automatically set up EBS volumes when the instance is launched.
 * The following interface represents a CfnLaunchConfiguration.BlockDeviceProperty intreface.
*/
export interface BlockDeviceProperty {
  /**
   * Indicates whether the EBS volume is deleted on instance termination.
   *
   * @default - Property not used.
   */
  readonly DeleteOnTermination?: boolean;

  /**
   * Indicates whether the encryption state of an EBS volume is changed while being restored from a backing snapshot.
   *
   * @default - Property not used.
   */
  readonly Encrypted?: boolean;

  /**
   * The number of I/O operations per second (IOPS).
   *
   * @default - Property not used.
   */
  readonly Iops?: number;

  /**
   * The ID of the snapshot.
   *
   * @default - Property not used.
   */
  readonly SnapshotId?: string;

  /**
   * The size of the volume, in GiBs.
   *
   * @default - Property not used.
   */
  readonly VolumeSize?: number;

  /**
   * The volume type.
   *
   * @default - Property not used.
   */
  readonly VolumeType?: string;
}

/**
 * The IAM instance profile.
 */
export interface SpotFleetInstanceProfile {
  /**
   * The Amazon Resource Name (ARN) of the instance profile.
   */
  readonly Arn: string;
}

/**
 * Describes a security group.
 */
export interface SpotFleetSecurityGroupId {
  readonly GroupId: string;
}

/**
 * The tags to apply to a resource when the resource is being created.
 */
export interface SpotFleetTagSpecification {
  /**
   * The type of resource to tag.
   */
  readonly ResourceType: string;

  /**
   * The tags to apply to the resource.
   */
  readonly Tags: SpotFleetTag[];
}

/**
 * Describes a tag.
 */
export interface SpotFleetTag {
  /**
   * The key of the tag.
   */
  readonly Key: string;

  /**
   * The value of the tag.
   */
  readonly Value: string;
}
