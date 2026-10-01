import { Global, Module } from '@nestjs/common';
import { STORAGE_PROVIDER, LocalManagedStorage } from './storage-provider.interface';

/**
 * Managed media storage. The local provider serves development and single-box
 * deployments through the `/media` static mount; a production S3-compatible
 * adapter swaps in by binding STORAGE_PROVIDER elsewhere (env-selected in a
 * later slice) without touching any call site.
 */
@Global()
@Module({
  providers: [{ provide: STORAGE_PROVIDER, useValue: new LocalManagedStorage() }],
  exports: [STORAGE_PROVIDER],
})
export class StorageModule {}
