import type { ReactNode } from 'react';
import { useHasGlobalPermission } from '@/hooks/useHasGlobalPermission';

interface PermissionGateProps {
  allow: string | string[];
  fallback?: ReactNode;
  children: ReactNode;
}

export function PermissionGate({ allow, fallback = null, children }: PermissionGateProps) {
  const isAllowed = useHasGlobalPermission(allow);
  return isAllowed ? <>{children}</> : <>{fallback}</>;
}
