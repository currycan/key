/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>

*/
// cmd/decrypt.go
package cmd

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/sha256"
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var decryptCmd = &cobra.Command{
	Use:   "decrypt",
	Short: "Decrypt a file",
	RunE: func(cmd *cobra.Command, args []string) error {
		input, _ := cmd.Flags().GetString("input")
		output, _ := cmd.Flags().GetString("output")
		key, _ := cmd.Flags().GetString("key")

		if input == "" || output == "" || key == "" {
			return fmt.Errorf("all flags (input, output, key) are required")
		}

		return decryptFile(input, output, key)
	},
}

func init() {
	decryptCmd.Flags().StringP("input", "i", "", "Input file to decrypt")
	decryptCmd.Flags().StringP("output", "o", "", "Output file path")
	decryptCmd.Flags().StringP("key", "k", "", "Decryption key")
}

func decryptFile(inputPath, outputPath, key string) error {
	hasher := sha256.New()
	hasher.Write([]byte(key))
	aesKey := hasher.Sum(nil)

	ciphertext, err := os.ReadFile(inputPath)
	if err != nil {
		return err
	}

	block, err := aes.NewCipher(aesKey)
	if err != nil {
		return err
	}

	if len(ciphertext) < aes.BlockSize {
		return fmt.Errorf("ciphertext too short")
	}

	iv := ciphertext[:aes.BlockSize]
	ciphertext = ciphertext[aes.BlockSize:]

	stream := cipher.NewCFBDecrypter(block, iv)
	plaintext := make([]byte, len(ciphertext))
	stream.XORKeyStream(plaintext, ciphertext)

	fmt.Println("File decrypted successfully")
	return os.WriteFile(outputPath, plaintext, 0644)
}
