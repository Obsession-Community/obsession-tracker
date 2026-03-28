import { Router, Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';

export const adminUploadsRouter = Router();

// Upload directory - mounted as Docker volume
const UPLOADS_DIR = process.env.UPLOADS_PATH || '/app/uploads';
const BASE_URL = process.env.UPLOADS_BASE_URL || 'https://api.obsessiontracker.com/uploads';

// Allowed MIME types and their extensions
const ALLOWED_TYPES: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/gif': '.gif',
  'image/webp': '.webp',
};

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

// Ensure upload directories exist
function ensureUploadDir(folder: string): string {
  const dir = path.join(UPLOADS_DIR, folder);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  return dir;
}

// Simple auth middleware - reuse from hunts.ts pattern
function requireAdminAuth(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  // Token validation is handled by the auth middleware in the main app
  // If we got here, the request has a valid token
  next();
}

/**
 * POST /admin/uploads
 * Upload an image file to local storage.
 *
 * Body: multipart/form-data with:
 *   - file: The image file
 *   - folder: Optional folder name (default: 'hunts')
 *
 * Returns: { success, url, key, filename, size, mimeType }
 */
adminUploadsRouter.post('/', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    // Check content type
    const contentType = req.headers['content-type'] || '';
    if (!contentType.includes('multipart/form-data')) {
      res.status(400).json({ error: 'Content-Type must be multipart/form-data' });
      return;
    }

    // Parse multipart data manually (no multer dependency)
    const chunks: Buffer[] = [];
    let totalSize = 0;

    await new Promise<void>((resolve, reject) => {
      req.on('data', (chunk: Buffer) => {
        totalSize += chunk.length;
        if (totalSize > MAX_FILE_SIZE + 10000) { // Allow some overhead for multipart headers
          reject(new Error('File too large'));
          return;
        }
        chunks.push(chunk);
      });
      req.on('end', resolve);
      req.on('error', reject);
    });

    const body = Buffer.concat(chunks);

    // Parse multipart boundary
    const boundaryMatch = contentType.match(/boundary=(?:"([^"]+)"|([^;]+))/);
    if (!boundaryMatch) {
      res.status(400).json({ error: 'Invalid multipart boundary' });
      return;
    }
    const boundary = boundaryMatch[1] || boundaryMatch[2];

    // Parse the multipart data
    const parts = parseMultipart(body, boundary);

    const filePart = parts.find(p => p.name === 'file');
    const folderPart = parts.find(p => p.name === 'folder');

    if (!filePart || !filePart.data || filePart.data.length === 0) {
      res.status(400).json({ error: 'No file provided' });
      return;
    }

    const folder = folderPart?.value || 'hunts';
    const mimeType = filePart.contentType || 'application/octet-stream';

    // Validate MIME type
    if (!ALLOWED_TYPES[mimeType]) {
      res.status(400).json({
        error: 'Invalid file type. Allowed: JPEG, PNG, GIF, WebP'
      });
      return;
    }

    // Validate file size
    if (filePart.data.length > MAX_FILE_SIZE) {
      res.status(400).json({ error: 'File too large. Maximum size: 5MB' });
      return;
    }

    // Validate magic bytes
    if (!validateMagicBytes(filePart.data, mimeType)) {
      res.status(400).json({ error: 'File content does not match declared type' });
      return;
    }

    // Generate unique filename
    const ext = ALLOWED_TYPES[mimeType];
    const filename = `${randomUUID()}${ext}`;

    // Ensure directory exists and save file
    const uploadDir = ensureUploadDir(folder);
    const filePath = path.join(uploadDir, filename);

    fs.writeFileSync(filePath, filePart.data);

    // Generate public URL
    const key = `${folder}/${filename}`;
    const url = `${BASE_URL}/${key}`;

    res.json({
      success: true,
      url,
      key,
      filename: filePart.filename || filename,
      size: filePart.data.length,
      mimeType,
    });

  } catch (error) {
    console.error('Upload error:', error);
    if (error instanceof Error && error.message === 'File too large') {
      res.status(413).json({ error: 'File too large. Maximum size: 5MB' });
    } else {
      res.status(500).json({ error: 'Upload failed' });
    }
  }
});

/**
 * DELETE /admin/uploads/:key
 * Delete an uploaded file.
 */
adminUploadsRouter.delete('/*', requireAdminAuth, (req: Request, res: Response) => {
  try {
    const key = req.params[0]; // Everything after /admin/uploads/
    if (!key) {
      res.status(400).json({ error: 'No file key provided' });
      return;
    }

    // Prevent path traversal
    const normalizedKey = path.normalize(key).replace(/^(\.\.(\/|\\|$))+/, '');
    const filePath = path.join(UPLOADS_DIR, normalizedKey);

    // Ensure file is within uploads directory
    if (!filePath.startsWith(UPLOADS_DIR)) {
      res.status(400).json({ error: 'Invalid file key' });
      return;
    }

    if (!fs.existsSync(filePath)) {
      res.status(404).json({ error: 'File not found' });
      return;
    }

    fs.unlinkSync(filePath);
    res.json({ success: true });

  } catch (error) {
    console.error('Delete error:', error);
    res.status(500).json({ error: 'Delete failed' });
  }
});

// ============================================================
// Multipart Parser (no external dependencies)
// ============================================================

interface MultipartPart {
  name: string;
  filename?: string;
  contentType?: string;
  data?: Buffer;
  value?: string;
}

function parseMultipart(body: Buffer, boundary: string): MultipartPart[] {
  const parts: MultipartPart[] = [];
  const boundaryBuffer = Buffer.from(`--${boundary}`);
  const endBoundary = Buffer.from(`--${boundary}--`);

  let start = body.indexOf(boundaryBuffer);
  if (start === -1) return parts;

  while (start !== -1) {
    // Move past boundary and CRLF
    start += boundaryBuffer.length;
    if (body[start] === 0x0D && body[start + 1] === 0x0A) {
      start += 2;
    }

    // Check if this is the end boundary
    if (body.slice(start - boundaryBuffer.length, start - boundaryBuffer.length + endBoundary.length).equals(endBoundary)) {
      break;
    }

    // Find end of headers (double CRLF)
    const headersEnd = body.indexOf(Buffer.from('\r\n\r\n'), start);
    if (headersEnd === -1) break;

    const headersStr = body.slice(start, headersEnd).toString('utf-8');

    // Find next boundary
    const nextBoundary = body.indexOf(boundaryBuffer, headersEnd + 4);
    const dataEnd = nextBoundary !== -1 ? nextBoundary - 2 : body.length; // -2 for CRLF before boundary

    // Parse headers
    const part: MultipartPart = { name: '' };
    const headers = headersStr.split('\r\n');

    for (const header of headers) {
      const [name, ...valueParts] = header.split(':');
      const value = valueParts.join(':').trim();

      if (name.toLowerCase() === 'content-disposition') {
        // Parse name and filename
        const nameMatch = value.match(/name="([^"]+)"/);
        const filenameMatch = value.match(/filename="([^"]+)"/);
        if (nameMatch) part.name = nameMatch[1];
        if (filenameMatch) part.filename = filenameMatch[1];
      } else if (name.toLowerCase() === 'content-type') {
        part.contentType = value;
      }
    }

    // Extract data
    const data = body.slice(headersEnd + 4, dataEnd);

    if (part.filename || part.contentType) {
      // Binary file data
      part.data = data;
    } else {
      // Text field value
      part.value = data.toString('utf-8');
    }

    parts.push(part);
    start = nextBoundary;
  }

  return parts;
}

// ============================================================
// Magic Byte Validation
// ============================================================

function validateMagicBytes(data: Buffer, mimeType: string): boolean {
  if (data.length < 4) return false;

  switch (mimeType) {
    case 'image/jpeg':
      // JPEG: FF D8 FF
      return data[0] === 0xFF && data[1] === 0xD8 && data[2] === 0xFF;

    case 'image/png':
      // PNG: 89 50 4E 47 0D 0A 1A 0A
      return data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47;

    case 'image/gif':
      // GIF: 47 49 46 38 (GIF8)
      return data[0] === 0x47 && data[1] === 0x49 && data[2] === 0x46 && data[3] === 0x38;

    case 'image/webp':
      // WebP: 52 49 46 46 ... 57 45 42 50 (RIFF...WEBP)
      return data[0] === 0x52 && data[1] === 0x49 && data[2] === 0x46 && data[3] === 0x46 &&
             data.length >= 12 && data[8] === 0x57 && data[9] === 0x45 && data[10] === 0x42 && data[11] === 0x50;

    default:
      return false;
  }
}
