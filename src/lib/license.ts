// License key generation and plan definitions for RescuePC
import crypto from 'crypto';

export type PlanCode = 'BASIC' | 'PRO' | 'ENTERPRISE' | 'LIFETIME' | 'GOVERNMENT' | 'ENTERPRISE-PACKAGE';

export interface PlanRights {
  code: PlanCode;
  label: string;
  description: string;
  personalUse: boolean;
  commercialUse: boolean;
  businessUse: boolean;
  remoteAssistIncluded: boolean;
  dedicatedSupport: boolean;
  lifetime: boolean;
  maxDevices: number;
}

/**
 * Get the rights and permissions for a given plan code
 */
export function getPlanRights(plan: PlanCode): PlanRights {
  switch (plan) {
    case 'BASIC':
      return {
        code: 'BASIC',
        label: 'Basic',
        description: 'Home and personal use on one PC.',
        personalUse: true,
        commercialUse: false,
        businessUse: false,
        remoteAssistIncluded: false,
        dedicatedSupport: false,
        lifetime: false,
        maxDevices: 1
      };

    case 'PRO':
      return {
        code: 'PRO',
        label: 'Professional',
        description: 'Use in paid repair work and client PCs.',
        personalUse: true,
        commercialUse: true,
        businessUse: false,
        remoteAssistIncluded: false,
        dedicatedSupport: false,
        lifetime: false,
        maxDevices: 1
      };

    case 'ENTERPRISE':
      return {
        code: 'ENTERPRISE',
        label: 'Enterprise',
        description: 'Business environments and managed fleets.',
        personalUse: true,
        commercialUse: true,
        businessUse: true,
        remoteAssistIncluded: true,
        dedicatedSupport: true,
        lifetime: false,
        maxDevices: 1
      };

    case 'LIFETIME':
      return {
        code: 'LIFETIME',
        label: 'Lifetime',
        description: 'Lifetime license on one machine.',
        personalUse: true,
        commercialUse: true,
        businessUse: false,
        remoteAssistIncluded: false,
        dedicatedSupport: false,
        lifetime: true,
        maxDevices: 1
      };

    case 'GOVERNMENT':
      return {
        code: 'GOVERNMENT',
        label: 'Government',
        description: 'Government and educational institutions.',
        personalUse: true,
        commercialUse: true,
        businessUse: true,
        remoteAssistIncluded: true,
        dedicatedSupport: true,
        lifetime: false,
        maxDevices: 1
      };

    case 'ENTERPRISE-PACKAGE':
      return {
        code: 'ENTERPRISE-PACKAGE',
        label: 'Enterprise Package',
        description: 'Enterprise license with additional benefits.',
        personalUse: true,
        commercialUse: true,
        businessUse: true,
        remoteAssistIncluded: true,
        dedicatedSupport: true,
        lifetime: false,
        maxDevices: 1
      };

    default:
      // Fallback to BASIC for unknown plan codes
      return getPlanRights('BASIC');
  }
}

// License key generation utility
// Generates secure, unique license keys in RPC-XXXX-XXXX-XXXX-XXXX-XXXX format
export function generateLicenseKey(): string {
  const raw = crypto.randomBytes(16).toString('hex').toUpperCase();
  const trimmed = raw.slice(0, 20); // 20 chars
  return 'RPC-' + trimmed.match(/.{1,4}/g)?.join('-'); // RPC-XXXX-XXXX-XXXX-XXXX-XXXX
}

// Legacy license key generator (UUID-based) - kept for backward compatibility
export function generateLegacyLicenseKey(): string {
  const uuid = crypto.randomUUID().replace(/-/g, "");
  const chunks = [
    uuid.slice(0, 5),
    uuid.slice(5, 10),
    uuid.slice(10, 15),
    uuid.slice(15, 20),
    uuid.slice(20, 25)
  ];
  return chunks.join("-").toUpperCase();
}

// Validate license key format
export function validateLicenseKeyFormat(key: string): boolean {
  const rpcPattern = /^RPC-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;
  const legacyPattern = /^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$/;
  return rpcPattern.test(key) || legacyPattern.test(key);
}

// Get standardized plan name from SKU or plan code
export function getPlanName(planCode: string): string {
  const rights = getPlanRights(planCode.toUpperCase() as PlanCode);
  return rights.label;
}

// Check if a plan has specific rights
export function hasPlanRight(planCode: string, right: keyof Omit<PlanRights, 'code' | 'label' | 'description' | 'maxDevices'>): boolean {
  const rights = getPlanRights(planCode.toUpperCase() as PlanCode);
  return rights[right] === true;
}
