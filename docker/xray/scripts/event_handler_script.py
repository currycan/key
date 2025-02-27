#!/usr/bin/env python
import sys

def main():
    while True:
        # 读取事件头部信息
        line = sys.stdin.readline()
        if not line:
            break

        # 打印事件信息
        sys.stderr.write(f"Received header: {line}")
        sys.stderr.flush()

        # 读取事件主体信息
        payload = sys.stdin.read(int(line.split()[1]))
        sys.stderr.write(f"Received payload: {payload}")
        sys.stderr.flush()

        # 返回 OK 表示成功处理
        sys.stdout.write("RESULT 2\nOK")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
