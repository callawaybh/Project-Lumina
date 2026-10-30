"""Local JSON API for a running Lumina development client (Python standard library)."""
import argparse
import json
import os
from pathlib import Path
import time
import uuid


def submit(project, command, timeout=90):
    inbox = Path(project) / '.lumina-bridge'
    if not (inbox / 'enabled').exists():
        raise RuntimeError('Bridge disabled. Run the enable command first.')
    request_id = uuid.uuid4().hex
    payload = dict(command, id=request_id)
    temporary = inbox / f'{request_id}.tmp'
    request = inbox / f'{request_id}.request.json'
    response = inbox / f'{request_id}.response.json'
    temporary.write_text(json.dumps(payload, allow_nan=False), encoding='utf-8')
    os.replace(temporary, request)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if response.exists():
            return json.loads(response.read_text(encoding='utf-8'))
        time.sleep(0.2)
    if request.exists():
        # Cancel an unclaimed command; do not let it run on a future launch.
        request.unlink(missing_ok=True)
        raise TimeoutError('Client did not pick up the request; cancelled. Restart client and join a local Space.')
    raise TimeoutError(f'Command {request_id} was claimed; outcome unknown. Inspect objects before retrying. Response: {response}')


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default=r'C:\Dev\LuminaClient\mirror-godot-app')
    parser.add_argument('--timeout', type=float, default=90)
    sub = parser.add_subparsers(dest='action', required=True)
    sub.add_parser('enable')
    sub.add_parser('disable')
    sub.add_parser('status')
    sub.add_parser('list_objects')
    sub.add_parser('list_groups')
    join = sub.add_parser('join_space')
    join.add_argument('space_id')
    create = sub.add_parser('create_primitive')
    create.add_argument('--shape', choices=['box', 'sphere', 'cylinder'], default='box')
    create.add_argument('--name', default='Lumina Primitive')
    create.add_argument('--position', nargs=3, type=float, required=True)
    create.add_argument('--size', nargs=3, type=float, default=[1, 1, 1])
    create.add_argument('--color', nargs=4, type=float, default=[1, 0, 0, 1])
    update = sub.add_parser('update_object')
    update.add_argument('object_id')
    update.add_argument('--position', nargs=3, type=float)
    update.add_argument('--rotation', nargs=3, type=float)
    update.add_argument('--scale', nargs=3, type=float)
    update.add_argument('--color', nargs=4, type=float)
    update.add_argument('--name')
    rename = sub.add_parser('rename_object')
    rename.add_argument('object_id')
    rename.add_argument('name')
    duplicate = sub.add_parser('duplicate_object')
    duplicate.add_argument('object_id')
    duplicate.add_argument('--name')
    duplicate.add_argument('--offset', nargs=3, type=float, default=[2, 0, 0])
    group = sub.add_parser('create_group')
    group.add_argument('name')
    group.add_argument('object_ids', nargs='+')
    rename_group = sub.add_parser('rename_group')
    rename_group.add_argument('group_id')
    rename_group.add_argument('name')
    move_group = sub.add_parser('move_group')
    move_group.add_argument('group_id')
    move_group.add_argument('--offset', nargs=3, type=float, required=True)
    duplicate_group = sub.add_parser('duplicate_group')
    duplicate_group.add_argument('group_id')
    duplicate_group.add_argument('name')
    duplicate_group.add_argument('--offset', nargs=3, type=float, required=True)
    return parser


def command_from_args(args):
    command = {'action': args.action}
    if args.action == 'join_space':
        command['space_id'] = args.space_id
    elif args.action == 'create_primitive':
        command.update({key: getattr(args, key) for key in ('shape', 'name', 'position', 'size', 'color')})
    elif args.action == 'update_object':
        command.update(object_id=args.object_id, changes={key: getattr(args, key)
            for key in ('name', 'position', 'rotation', 'scale', 'color') if getattr(args, key) is not None})
    elif args.action == 'rename_object':
        command.update(object_id=args.object_id, name=args.name)
    elif args.action == 'duplicate_object':
        command.update(object_id=args.object_id, offset=args.offset)
        if args.name is not None:
            command['name'] = args.name
    elif args.action == 'create_group':
        command.update(name=args.name, object_ids=args.object_ids)
    elif args.action == 'rename_group':
        command.update(group_id=args.group_id, name=args.name)
    elif args.action in ('move_group', 'duplicate_group'):
        command.update(group_id=args.group_id, offset=args.offset)
        if args.action == 'duplicate_group':
            command['name'] = args.name
    return command


def main():
    args = build_parser().parse_args()
    inbox = Path(args.project) / '.lumina-bridge'
    if args.action in ('enable', 'disable'):
        inbox.mkdir(exist_ok=True)
        marker = inbox / 'enabled'
        if args.action == 'enable':
            marker.touch()
        else:
            marker.unlink(missing_ok=True)
        print(json.dumps({'ok': True, 'enabled': marker.exists()}))
        return
    command = command_from_args(args)
    result = submit(args.project, command, args.timeout)
    print(json.dumps(result, indent=2))
    if not result.get('ok'):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
