import { ArgumentMetadata, BadRequestException, ValidationPipe } from '@nestjs/common';
import { RequestOtpDto, SignUpDto, VerifyOtpDto } from './auth.dto';

/**
 * Contract tests for the auth request DTOs.
 *
 * These run the EXACT ValidationPipe configuration used by `main.ts`
 * (`whitelist + forbidNonWhitelisted + transform`, no implicit conversion) so
 * the wire contract asserted here is the contract the running server enforces.
 */
describe('Auth DTO contract (ValidationPipe)', () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
    transformOptions: { enableImplicitConversion: false },
  });

  async function transform<T extends object>(
    metatype: new () => T,
    value: unknown,
  ): Promise<T> {
    return pipe.transform(value, {
      type: 'body',
      metatype,
    } as ArgumentMetadata) as Promise<T>;
  }

  async function expectRejected(
    metatype: new () => object,
    value: unknown,
  ): Promise<string[]> {
    try {
      await transform(metatype, value);
    } catch (err) {
      expect(err).toBeInstanceOf(BadRequestException);
      const response = (err as BadRequestException).getResponse() as {
        message: string[];
      };
      return response.message;
    }
    throw new Error('Expected validation to reject the payload, but it passed.');
  }

  describe('SignUpDto — camelCase contract', () => {
    it('accepts the canonical camelCase payload and returns the DTO', async () => {
      const dto = await transform(SignUpDto, {
        phoneNumber: '+919876543210',
        displayName: 'Aarav Sharma',
        role: 'customer',
      });

      expect(dto.phoneNumber).toBe('+919876543210');
      expect(dto.displayName).toBe('Aarav Sharma');
      expect(dto.role).toBe('customer');
    });

    it('rejects snake_case `phone_number` (forbidNonWhitelisted)', async () => {
      const messages = await expectRejected(SignUpDto, {
        phone_number: '+919876543210',
        displayName: 'Aarav Sharma',
        role: 'customer',
      });
      expect(messages.join('; ')).toMatch(/property phone_number should not exist/);
    });

    it('rejects snake_case `display_name` (forbidNonWhitelisted)', async () => {
      const messages = await expectRejected(SignUpDto, {
        phoneNumber: '+919876543210',
        display_name: 'Aarav Sharma',
        role: 'customer',
      });
      expect(messages.join('; ')).toMatch(/property display_name should not exist/);
    });

    it('rejects a non-string phoneNumber (must be a JSON string)', async () => {
      const messages = await expectRejected(SignUpDto, {
        phoneNumber: 919876543210,
        displayName: 'Aarav Sharma',
        role: 'customer',
      });
      expect(messages.join('; ')).toMatch(/phoneNumber must be a string/);
    });

    it('rejects invalid phone numbers (spaces, missing +, bad prefix)', async () => {
      for (const phoneNumber of [
        '9876543210', // no country code
        '+91 98765 43210', // whitespace/formatting
        '+9198765432', // too short
        '+911234567890', // subscriber must start 6-9
        '+9198765432109999', // too long
      ]) {
        const messages = await expectRejected(SignUpDto, {
          phoneNumber,
          displayName: 'Aarav Sharma',
          role: 'customer',
        });
        expect(messages.length).toBeGreaterThan(0);
      }
    });

    it('rejects a displayName shorter than 2 characters', async () => {
      const messages = await expectRejected(SignUpDto, {
        phoneNumber: '+919876543210',
        displayName: 'A',
        role: 'customer',
      });
      expect(messages.join('; ')).toMatch(/displayName must be longer than or equal to 2/);
    });

    it('rejects a non-string displayName', async () => {
      const messages = await expectRejected(SignUpDto, {
        phoneNumber: '+919876543210',
        displayName: 42,
        role: 'customer',
      });
      expect(messages.join('; ')).toMatch(/displayName must be a string/);
    });

    it('rejects unknown properties entirely', async () => {
      const messages = await expectRejected(SignUpDto, {
        phoneNumber: '+919876543210',
        displayName: 'Aarav Sharma',
        role: 'customer',
        isAdmin: true,
      });
      expect(messages.join('; ')).toMatch(/property isAdmin should not exist/);
    });

    it('rejects admin role values, keeping public signup customer/driver only', async () => {
      const messages = await expectRejected(SignUpDto, {
        phoneNumber: '+919876543210',
        displayName: 'Aarav Sharma',
        role: 'superAdmin',
      });
      expect(messages.join('; ')).toMatch(/role must be one of the following values/);
    });
  });

  describe('RequestOtpDto', () => {
    it('accepts the canonical camelCase payload', async () => {
      const dto = await transform(RequestOtpDto, {
        phoneNumber: '+919810000001',
        purpose: 'LOGIN',
      });
      expect(dto.phoneNumber).toBe('+919810000001');
      expect(dto.purpose).toBe('LOGIN');
    });

    it('rejects snake_case `phone_number`', async () => {
      const messages = await expectRejected(RequestOtpDto, {
        phone_number: '+919810000001',
      });
      expect(messages.join('; ')).toMatch(/property phone_number should not exist/);
    });
  });

  describe('VerifyOtpDto', () => {
    it('accepts sessionId + 6-digit otpCode', async () => {
      const dto = await transform(VerifyOtpDto, {
        sessionId: '0bd9c4b1b0a94e9b8f4e2d1c3a5b6c7d',
        otpCode: '849201',
      });
      expect(dto.otpCode).toBe('849201');
    });

    it('rejects snake_case `otp_code`', async () => {
      const messages = await expectRejected(VerifyOtpDto, {
        sessionId: '0bd9c4b1b0a94e9b8f4e2d1c3a5b6c7d',
        otp_code: '849201',
      });
      expect(messages.join('; ')).toMatch(/property otp_code should not exist/);
    });
  });
});
