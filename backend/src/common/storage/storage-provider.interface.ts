import { BadRequestAppException } from '../../auth/errors/auth.exceptions';
import { ErrorCode } from '../../common/errors/error-codes';

export const STORAGE_PROVIDER = 'STORAGE_PROVIDER';

/**
 * Storage abstraction (managed media). Concrete providers implement this
 * interface; business code never touches disk paths or object-store SDKs.
 *
 * LocalManagedStorage (default) writes under MEDIA_ROOT and is served by the
 * existing `/media` static mount. An S3-compatible adapter implements the
 * same interface for production without touching call sites.
 *
 * Missing production credentials must FAIL LOUDLY — never fake an upload.
 */
export interface StoredObject {
  /** Server-relative URL served to clients (e.g. `/media/vehicles/x.jpg`). */
  url: string;
  /** Storage key (stable identifier; rename-safe). */
  key: string;
  bytes: number;
  mimeType: string;
}

export interface StorageProvider {
  readonly name: string;
  /**
   * Persists an upload and returns its public URL. Throws StorageError on
   * any failure — a failed upload must never yield a fake success.
   */
  put(input: {
    scope: 'vehicles' | 'documents' | 'partners';
    fileName: string;
    mimeType: string;
    bytes: Buffer;
  }): Promise<StoredObject>;
  /** Removes a previously stored object (idempotent). */
  delete(key: string): Promise<void>;
}

/** Raised for any storage failure; never swallows into fake success. */
export class StorageError extends Error {
  readonly provider: string;
  constructor(provider: string, message: string) {
    super(`[${provider}] ${message}`);
    this.name = 'StorageError';
    this.provider = provider;
  }
}

/** Extensions/keys are normalized; the extension itself is validated by the caller. */
function safeName(fileName: string): string {
  const base = fileName.split(/[\\/]/).pop() ?? 'file';
  const ext = base.includes('.') ? base.slice(base.lastIndexOf('.')).toLowerCase() : '';
  const stem =
    base
      .slice(0, base.includes('.') ? base.lastIndexOf('.') : undefined)
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 48) || 'file';
  return `${stem}${ext}`;
}

/**
 * Local managed storage. Writes under `<MEDIA_ROOT>/<scope>/…` with a random
 * prefix so partner uploads can never overwrite one another's files.
 */
export class LocalManagedStorage implements StorageProvider {
  readonly name = 'local';
  private readonly root: string;

  constructor(env: Record<string, string | undefined> = process.env) {
    this.root = env.MEDIA_ROOT ?? `${process.cwd()}/public/media`;
  }

  async put(input: {
    scope: 'vehicles' | 'documents' | 'partners';
    fileName: string;
    mimeType: string;
    bytes: Buffer;
  }): Promise<StoredObject> {
    const { randomUUID } = await import('crypto');
    const { mkdir, writeFile } = await import('fs/promises');
    const { join } = await import('path');

    const dir = join(this.root, input.scope);
    const key = `${input.scope}/${randomUUID().slice(0, 8)}-${safeName(input.fileName)}`;
    try {
      await mkdir(dir, { recursive: true });
      await writeFile(join(this.root, key), input.bytes);
    } catch (err) {
      throw new StorageError(this.name, `write failed: ${String(err)}`);
    }
    return {
      url: `/media/${key}`,
      key,
      bytes: input.bytes.length,
      mimeType: input.mimeType,
    };
  }

  async delete(key: string): Promise<void> {
    const { unlink } = await import('fs/promises');
    const { join } = await import('path');
    try {
      await unlink(join(this.root, key));
    } catch {
      // Idempotent: deleting a missing object is fine.
    }
  }
}

/** Image MIME types accepted for vehicle photos. */
export const IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export const IMAGE_MAX_BYTES = 8 * 1024 * 1024;

/** Document MIME types accepted for RC/insurance/PUC uploads. */
export const DOCUMENT_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
] as const;
export const DOCUMENT_MAX_BYTES = 12 * 1024 * 1024;

export function assertUploadAllowed(
  mimeType: string,
  bytes: number,
  allowed: readonly string[],
  maxBytes: number,
  kind: string,
): void {
  if (!allowed.includes(mimeType)) {
    throw new BadRequestAppException(
      ErrorCode.VALIDATION_FAILED,
      `${kind}: unsupported file type '${mimeType}'. Allowed: ${allowed.join(', ')}.`,
    );
  }
  if (bytes <= 0) {
    throw new BadRequestAppException(ErrorCode.VALIDATION_FAILED, `${kind}: empty file.`);
  }
  if (bytes > maxBytes) {
    throw new BadRequestAppException(
      ErrorCode.VALIDATION_FAILED,
      `${kind}: file exceeds ${(maxBytes / (1024 * 1024)).toFixed(0)} MB limit.`,
    );
  }
}
