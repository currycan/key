/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>

*/
// cmd/encrypt.go
package cmd

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var encryptCmd = &cobra.Command{
	Use:   "encrypt",
	Short: "Encrypt a file",
	RunE: func(cmd *cobra.Command, args []string) error {
		input, _ := cmd.Flags().GetString("input")
		output, _ := cmd.Flags().GetString("output")
		key, _ := cmd.Flags().GetString("key")

		// Validate parameters
		if input == "" || output == "" || key == "" {
			return fmt.Errorf("all flags (input, output, key) are required")
		}

		return encryptFile(input, output, key)
	},
}

func init() {
	encryptCmd.Flags().StringP("input", "i", "", "Input file to encrypt")
	encryptCmd.Flags().StringP("output", "o", "", "Output file path")
	encryptCmd.Flags().StringP("key", "k", "", "Encryption key")
}

func encryptFile(inputPath, outputPath, key string) error {
	// Generate 256-bit key from string
	hasher := sha256.New()
	hasher.Write([]byte(key))
	aesKey := hasher.Sum(nil)

	// Read input file
	plaintext, err := os.ReadFile(inputPath)
	if err != nil {
		return err
	}

	// Create cipher block
	block, err := aes.NewCipher(aesKey)
	if err != nil {
		return err
	}

	// Create output file
	outFile, err := os.Create(outputPath)
	if err != nil {
		return err
	}
	defer outFile.Close()

	// Generate IV
	iv := make([]byte, aes.BlockSize)
	if _, err := rand.Read(iv); err != nil {
		return err
	}

	// Write IV to file
	if _, err = outFile.Write(iv); err != nil {
		return err
	}

	// Create CFB encryptor
	stream := cipher.NewCFBEncrypter(block, iv)
	ciphertext := make([]byte, len(plaintext))
	stream.XORKeyStream(ciphertext, plaintext)

	// Write encrypted data
	if _, err = outFile.Write(ciphertext); err != nil {
		return err
	}

	fmt.Println("File encrypted successfully")
	return nil
}
