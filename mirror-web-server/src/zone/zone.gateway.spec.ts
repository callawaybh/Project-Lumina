import { Test, TestingModule } from '@nestjs/testing'
import { ZoneGateway } from './zone.gateway'
import { ZoneService } from './zone.service'
import { SpaceManagerExternalService } from './space-manager-external.service'
import { LoggerModule } from '../util/logger/logger.module'
import { WsAuthHelperService } from '../godot-server/ws-auth-helper.service'
import { GodotSocketInterceptor } from '../godot-server/godot-socket.interceptor'
import { Logger } from '@nestjs/common'
import { lastValueFrom, of } from 'rxjs'
import { UserService } from '../user/user.service'

describe('ZoneGateway', () => {
  let gateway: ZoneGateway
  let findPublicUser: ReturnType<typeof vi.fn>

  beforeEach(async () => {
    findPublicUser = vi.fn()
    const module: TestingModule = await Test.createTestingModule({
      imports: [LoggerModule],
      providers: [
        ZoneGateway,
        { provide: ZoneService, useValue: {} },
        { provide: SpaceManagerExternalService, useValue: {} },
        { provide: WsAuthHelperService, useValue: {} },
        { provide: UserService, useValue: { findPublicUser } }
      ]
    }).compile()

    gateway = module.get<ZoneGateway>(ZoneGateway)
  })

  it('should be defined', () => {
    expect(gateway).toBeDefined()
  })

  it('returns the public profile through the authenticated websocket gateway', async () => {
    const id = '6ae46e485754d729b3dbf613'
    const profile = { _id: id, displayName: 'Test Player' }
    findPublicUser.mockResolvedValue(profile)
    await expect(gateway.getPublicUser(id)).resolves.toEqual(profile)
    expect(findPublicUser).toHaveBeenCalledWith(id)
  })

  it('rejects malformed IDs before querying users', async () => {
    await expect(gateway.getPublicUser('invalid')).rejects.toThrow(
      'Invalid user ID'
    )
    expect(findPublicUser).not.toHaveBeenCalled()
  })

  it('reports a missing user instead of passing null into the response formatter', async () => {
    findPublicUser.mockResolvedValue(null)
    await expect(
      gateway.getPublicUser('6ae46e485754d729b3dbf613')
    ).rejects.toThrow('User not found')
  })

  it('acknowledges a personal localhost heartbeat without calling admin services', async () => {
    // The empty service mocks deliberately cannot perform cloud mutations.
    await expect(
      gateway.updateStatus(false, 'localhost', 1, 0, 'local', [])
    ).resolves.toEqual({})
  })

  it('formats a personal heartbeat as a successful websocket response', async () => {
    const response = await gateway.updateStatus(
      false,
      'localhost',
      1,
      0,
      'local',
      []
    )
    const interceptor = new GodotSocketInterceptor(new Logger())
    const context = {
      switchToWs: () => ({ getData: () => ({ eventId: 'heartbeat-test' }) })
    }
    await expect(
      lastValueFrom(
        interceptor.intercept(
          context as any,
          {
            handle: () => of(response)
          } as any
        )
      )
    ).resolves.toEqual({
      eventId: 'heartbeat-test',
      status: 200,
      result: {}
    })
  })

  it('continues acknowledging admin localhost heartbeats without cloud mutations', async () => {
    await expect(
      gateway.updateStatus(true, 'localhost', 0, 1000, 'local', [])
    ).resolves.toEqual({})
  })
})
